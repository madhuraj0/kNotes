import Foundation
import AppKit

public final class ProcessManager: @unchecked Sendable {
    public static let shared = ProcessManager()

    private var backendProcess: Process?
    public private(set) var lastError: String?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    deinit {
        stopBackend()
    }

    public func ensureBackendRunning() async -> Bool {
        // 1. Check if backend is already responding
        if await isBackendResponsive() {
            print("[KNotes] Backend is already running.")
            return true
        }

        print("[KNotes] Ensuring Python environment...")
        guard let pythonPath = await preparePythonEnvironment() else {
            print("[KNotes] Python environment could not be prepared: \(lastError ?? "Unknown error")")
            return false
        }

        print("[KNotes] Starting local backend daemon using \(pythonPath)...")
        startBackend(with: pythonPath)

        // Wait up to ~15 seconds for backend to become responsive
        for _ in 0..<45 {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if await isBackendResponsive() {
                print("[KNotes] Backend daemon is ready.")
                return true
            }
        }

        print("[KNotes] Backend failed to respond in time.")
        if lastError == nil {
            lastError = "Backend service timed out during startup. Check ~/.knotes/backend.log for details."
        }
        return false
    }

    private func isBackendResponsive() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:8765/api/status") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                return true
            }
        } catch {
            return false
        }
        return false
    }

    /// Prepares and validates a standalone Python virtual environment in ~/.knotes/venv.
    /// Completely isolated from ~/Downloads and system directories.
    private func preparePythonEnvironment() async -> String? {
        let fileManager = FileManager.default
        let home = NSHomeDirectory()
        let knotesDir = "\(home)/.knotes"
        let venvDir = "\(knotesDir)/venv"
        let venvPython = "\(venvDir)/bin/python3"

        // 1. Ensure ~/.knotes base directory exists
        if !fileManager.fileExists(atPath: knotesDir) {
            try? fileManager.createDirectory(
                atPath: knotesDir,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        }

        // 2. Sync backend scripts from application bundle to ~/.knotes/backend if available
        syncBundledBackend(to: "\(knotesDir)/backend")

        // 3. Remove legacy symbolic links (which previously linked to ~/Downloads)
        let venvURL = URL(fileURLWithPath: venvDir)
        var isSymlink = false
        if let res = try? venvURL.resourceValues(forKeys: [.isSymbolicLinkKey]), res.isSymbolicLink == true {
            isSymlink = true
        } else if let attrs = try? fileManager.attributesOfItem(atPath: venvDir),
                  let type = attrs[.type] as? FileAttributeType, type == .typeSymbolicLink {
            isSymlink = true
        }
        if isSymlink {
            print("[KNotes] Detected legacy symlink at \(venvDir). Removing it...")
            try? fileManager.removeItem(atPath: venvDir)
        }

        // 4. Check if existing ~/.knotes/venv has functional dependencies
        if fileManager.fileExists(atPath: venvPython) && testPythonDependencies(executable: venvPython) {
            print("[KNotes] Valid isolated Python environment found: \(venvPython)")
            return venvPython
        }

        // 5. Locate a working system base Python 3 to build the virtual environment
        print("[KNotes] Virtual environment missing or incomplete. Locating system Python 3...")
        guard let basePython = findSystemPython() else {
            promptUserToInstallPython()
            return nil
        }

        print("[KNotes] Creating isolated virtual environment at \(venvDir) using \(basePython)...")
        if fileManager.fileExists(atPath: venvDir) {
            try? fileManager.removeItem(atPath: venvDir)
        }

        let venvSuccess = await runProcessAsync(
            executable: basePython,
            arguments: ["-m", "venv", venvDir],
            timeout: 60
        )

        guard venvSuccess, fileManager.fileExists(atPath: venvPython) else {
            self.lastError = "Failed to create Python virtual environment at ~/.knotes/venv."
            return nil
        }

        // 6. Install required packages into the isolated virtual environment
        print("[KNotes] Installing required dependencies into ~/.knotes/venv...")
        let reqFile = "\(knotesDir)/backend/requirements.txt"
        let pipArgs: [String]
        if fileManager.fileExists(atPath: reqFile) {
            pipArgs = ["-m", "pip", "install", "--quiet", "--disable-pip-version-check", "--no-warn-script-location", "-r", reqFile]
        } else {
            pipArgs = [
                "-m", "pip", "install", "--quiet", "--disable-pip-version-check", "--no-warn-script-location",
                "gkeepapi>=0.17.1", "fastapi>=0.115.0", "uvicorn>=0.30.0", "pydantic>=2.8.0", "httpx>=0.27.0"
            ]
        }

        let pipSuccess = await runProcessAsync(
            executable: venvPython,
            arguments: pipArgs,
            timeout: 180
        )

        guard pipSuccess && testPythonDependencies(executable: venvPython) else {
            self.lastError = "Failed to install Python dependencies. Please verify your internet connection."
            return nil
        }

        print("[KNotes] Python environment is ready at \(venvPython).")
        return venvPython
    }

    /// Copies backend scripts from the Application bundle to ~/.knotes/backend
    private func syncBundledBackend(to destinationPath: String) {
        guard let resourcePath = Bundle.main.resourcePath else { return }
        let bundledBackend = "\(resourcePath)/backend"
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: "\(bundledBackend)/run.py") else { return }

        if !fileManager.fileExists(atPath: destinationPath) {
            try? fileManager.copyItem(atPath: bundledBackend, toPath: destinationPath)
        } else {
            let filesToSync = ["app", "run.py", "requirements.txt", "run_backend.sh"]
            for name in filesToSync {
                let src = "\(bundledBackend)/\(name)"
                let dst = "\(destinationPath)/\(name)"
                if fileManager.fileExists(atPath: src) && !fileManager.fileExists(atPath: dst) {
                    try? fileManager.copyItem(atPath: src, toPath: dst)
                }
            }
        }
    }

    /// Verifies that the given Python executable can import required packages.
    private func testPythonDependencies(executable: String) -> Bool {
        let home = NSHomeDirectory()
        let knotesDir = "\(home)/.knotes"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.currentDirectoryURL = URL(fileURLWithPath: knotesDir)
        process.environment = cleanEnvironment(venv: "\(knotesDir)/venv")
        process.arguments = ["-c", "import sys, gkeepapi, fastapi, uvicorn, pydantic; sys.exit(0)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(4.0)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                process.terminate()
                return false
            }
            if process.terminationStatus != 0 {
                let errData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                print("[KNotes] Dependency test failed (exit code \(process.terminationStatus)): \(errStr.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            return process.terminationStatus == 0
        } catch {
            print("[KNotes] Dependency test execution error: \(error)")
            return false
        }
    }

    /// Locates a functional base Python 3 executable on macOS.
    private func findSystemPython() -> String? {
        let candidates = [
            "/opt/homebrew/bin/python3.12",
            "/opt/homebrew/bin/python3.13",
            "/opt/homebrew/bin/python3.11",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/usr/bin/python3"
        ]

        let fileManager = FileManager.default
        for candidate in candidates {
            if fileManager.isExecutableFile(atPath: candidate) && isPythonFunctional(candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Tests if a Python binary runs and is Python 3.9+.
    private func isPythonFunctional(_ executable: String) -> Bool {
        let home = NSHomeDirectory()
        let knotesDir = "\(home)/.knotes"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.currentDirectoryURL = URL(fileURLWithPath: knotesDir)
        process.environment = cleanEnvironment()
        process.arguments = ["-c", "import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(3.0)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                process.terminate()
                return false
            }
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Builds a sanitized, non-leaking environment for all Python processes.
    /// Completely strips inherited PYTHONPATH, PYTHONHOME, and parent VIRTUAL_ENV (e.g. from ~/Downloads).
    private func cleanEnvironment(venv: String? = nil) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "PYTHONPATH")
        env.removeValue(forKey: "PYTHONHOME")
        env.removeValue(forKey: "VIRTUAL_ENV")

        let home = NSHomeDirectory()
        let venvBin = venv != nil ? "\(venv!)/bin" : "\(home)/.knotes/venv/bin"
        env["PATH"] = "\(venvBin):/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

        if let venv = venv {
            env["VIRTUAL_ENV"] = venv
        } else if FileManager.default.fileExists(atPath: "\(home)/.knotes/venv") {
            env["VIRTUAL_ENV"] = "\(home)/.knotes/venv"
        }

        env["PYTHONUNBUFFERED"] = "1"
        return env
    }

    /// Informs the user when no base Python 3 is installed and offers one-click install options.
    private func promptUserToInstallPython() {
        self.lastError = "Python 3 is required by kNotes. Please install Python 3 and reopen the app."
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Python 3 Required"
            alert.informativeText = "kNotes requires Python 3 to connect with Google Keep.\n\nWould you like to install Apple Command Line Tools (includes Python 3) or download Python from python.org?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Install Apple Command Line Tools")
            alert.addButton(withTitle: "Download Python (python.org)")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
                task.arguments = ["--install"]
                try? task.run()
            } else if response == .alertSecondButtonReturn {
                if let url = URL(string: "https://www.python.org/downloads/macos/") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    /// Asynchronously runs a command while writing output to ~/.knotes/setup.log without blocking.
    private func runProcessAsync(executable: String, arguments: [String], timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let home = NSHomeDirectory()
                let knotesDir = "\(home)/.knotes"
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.currentDirectoryURL = URL(fileURLWithPath: knotesDir)
                process.environment = self.cleanEnvironment(venv: "\(knotesDir)/venv")
                process.arguments = arguments

                let logPath = "\(knotesDir)/setup.log"
                if !FileManager.default.fileExists(atPath: logPath) {
                    FileManager.default.createFile(atPath: logPath, contents: nil, attributes: [.posixPermissions: 0o600])
                }
                if let logHandle = FileHandle(forWritingAtPath: logPath) {
                    logHandle.seekToEndOfFile()
                    let timestamp = ISO8601DateFormatter().string(from: Date())
                    let banner = "\n--- [\(timestamp)] \(executable) \(arguments.joined(separator: " ")) ---\n"
                    if let data = banner.data(using: .utf8) {
                        logHandle.write(data)
                    }
                    process.standardOutput = logHandle
                    process.standardError = logHandle
                }

                do {
                    try process.run()
                } catch {
                    print("[KNotes] Process execution error: \(error)")
                    continuation.resume(returning: false)
                    return
                }

                let deadline = Date().addingTimeInterval(timeout)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.1)
                }

                if process.isRunning {
                    print("[KNotes] Process timed out, terminating...")
                    process.terminate()
                    continuation.resume(returning: false)
                    return
                }

                continuation.resume(returning: process.terminationStatus == 0)
            }
        }
    }

    private func startBackend(with pythonPath: String) {
        let fileManager = FileManager.default
        let home = NSHomeDirectory()
        let knotesDir = "\(home)/.knotes"

        let candidateScriptPaths = [
            Bundle.main.resourcePath.map { "\($0)/backend/run.py" },
            "\(knotesDir)/backend/run.py"
        ].compactMap { $0 }

        var scriptPath: String?
        for path in candidateScriptPaths {
            if fileManager.fileExists(atPath: path) {
                scriptPath = path
                break
            }
        }

        guard let selectedScript = scriptPath else {
            print("[KNotes] Error: backend/run.py not found.")
            self.lastError = "Could not find backend/run.py script."
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.currentDirectoryURL = URL(fileURLWithPath: knotesDir)
        process.arguments = [selectedScript]
        process.environment = cleanEnvironment(venv: "\(knotesDir)/venv")

        // Redirect stdout/stderr to ~/.knotes/backend.log with 5MB rotation
        let logPath = "\(knotesDir)/backend.log"
        if fileManager.fileExists(atPath: logPath) {
            if let attrs = try? fileManager.attributesOfItem(atPath: logPath),
               let size = attrs[.size] as? UInt64, size > 5 * 1024 * 1024 {
                let backupLog = "\(knotesDir)/backend.log.1"
                try? fileManager.removeItem(atPath: backupLog)
                try? fileManager.moveItem(atPath: logPath, toPath: backupLog)
            }
        }
        if !fileManager.fileExists(atPath: logPath) {
            fileManager.createFile(atPath: logPath, contents: nil, attributes: [.posixPermissions: 0o600])
        } else {
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: logPath)
        }
        if let logHandle = FileHandle(forWritingAtPath: logPath) {
            logHandle.seekToEndOfFile()
            process.standardOutput = logHandle
            process.standardError = logHandle
        }

        do {
            try process.run()
            self.backendProcess = process
            print("[KNotes] Spawned backend process with PID: \(process.processIdentifier)")
        } catch {
            print("[KNotes] Failed to start backend: \(error)")
            self.lastError = "Failed to launch backend process: \(error.localizedDescription)"
        }
    }

    public func stopBackend() {
        if let process = backendProcess, process.isRunning {
            print("[KNotes] Terminating backend process PID: \(process.processIdentifier)")
            process.terminate()
            backendProcess = nil
        }
    }

    @objc private func handleAppWillTerminate() {
        stopBackend()
    }
}
