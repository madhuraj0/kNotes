import Foundation
import AppKit

public final class ProcessManager {
    public static let shared = ProcessManager()

    private var backendProcess: Process?

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

        print("[KNotes] Starting local backend daemon...")
        startBackend()

        // Wait up to 6 seconds for backend to become responsive
        for _ in 0..<12 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if await isBackendResponsive() {
                print("[KNotes] Backend daemon is ready.")
                return true
            }
        }

        print("[KNotes] Backend failed to respond in time.")
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

    private func startBackend() {
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let home = NSHomeDirectory()

        let candidatePythonPaths = [
            "\(home)/.knotes/venv/bin/python3",
            "\(home)/Downloads/code/KNotes/.venv/bin/python3",
            Bundle.main.resourcePath.map { "\($0)/backend/.venv/bin/python3" },
            "\(currentDir)/.venv/bin/python3",
            "/opt/homebrew/bin/python3.12",
            "/opt/homebrew/bin/python3"
        ].compactMap { $0 }

        var pythonPath: String?
        for path in candidatePythonPaths {
            if fileManager.fileExists(atPath: path) {
                pythonPath = path
                break
            }
        }

        guard let selectedPython = pythonPath else {
            print("[KNotes] Error: Python 3 not found.")
            return
        }

        let candidateScriptPaths = [
            Bundle.main.resourcePath.map { "\($0)/backend/run.py" },
            "\(home)/.knotes/backend/run.py",
            "\(home)/Downloads/code/KNotes/backend/run.py",
            "\(currentDir)/backend/run.py"
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
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: selectedPython)
        process.arguments = [selectedScript]

        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        env["PATH"] = "\(home)/.knotes/venv/bin:\(home)/Downloads/code/KNotes/.venv/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        if selectedPython.contains("venv") {
            let venvDir = URL(fileURLWithPath: selectedPython).deletingLastPathComponent().deletingLastPathComponent().path
            env["VIRTUAL_ENV"] = venvDir
        }
        process.environment = env

        // Redirect stdout/stderr to ~/.knotes/backend.log
        let logPath = "\(home)/.knotes/backend.log"
        if !fileManager.fileExists(atPath: logPath) {
            fileManager.createFile(atPath: logPath, contents: nil)
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
