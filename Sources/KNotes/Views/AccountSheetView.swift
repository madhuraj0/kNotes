import SwiftUI
import AppKit

public struct AccountSheetView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.dismiss) private var dismiss

    @State private var showEmbeddedBrowser: Bool = false
    @State private var isWebLoading: Bool = false
    @State private var manualEmail: String = ""
    @State private var manualToken: String = ""
    @State private var showManualSetup: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isConnecting: Bool = false

    public init(store: NotesStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showEmbeddedBrowser {
                embeddedBrowserView
            } else {
                mainContentView
            }
        }
        .frame(width: showEmbeddedBrowser ? 520 : 480)
        .frame(minHeight: showEmbeddedBrowser ? 600 : 420, maxHeight: 650)
    }

    // MARK: - Main Account View
    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 36))
                        .foregroundColor(.yellow)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Keep Account")
                            .font(.system(size: 18, weight: .bold))
                        Text("Sync notes bidirectionally with Google Keep in the cloud")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 4)

                Divider()

                if store.status?.authenticated == true {
                    connectedAccountView
                } else {
                    signInOptionsView
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
    }

    // MARK: - Connected Account State
    private var connectedAccountView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Connected to Google Keep")
                        .font(.system(size: 14, weight: .semibold))
                    Text(store.status?.email ?? "Account Connected")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.green.opacity(0.1))
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Total Notes:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(store.status?.totalNotes ?? 0)")
                        .font(.system(size: 12, weight: .medium))
                }
                HStack {
                    Text("Sync Status:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(store.status?.syncStatus.capitalized ?? "Synced")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
                if let lastSync = store.status?.lastSynced {
                    HStack {
                        Text("Last Synced:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(lastSync)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)

            HStack(spacing: 12) {
                Button("Sync Now") {
                    store.syncNow()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(role: .destructive) {
                    Task {
                        await store.logout()
                    }
                } label: {
                    Text("Sign Out")
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Sign In Options
    private var signInOptionsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Friendly Explainer Card
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                        .font(.system(size: 13, weight: .bold))
                    Text("Seamless 1-Click Sign In")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text("Click the button below to sign in directly with your Google account. KNotes will automatically establish a secure connection and sync your Google Keep notes.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(Color.yellow.opacity(0.12))
            .cornerRadius(10)

            // Primary 1-Click Sign In Button
            Button {
                showEmbeddedBrowser = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 15))
                    Text("Sign in with Google")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let msg = statusMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text(msg)
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            Divider()
                .padding(.vertical, 4)

            // Collapsible Manual / CLI Options for Advanced Users
            DisclosureGroup(isExpanded: $showManualSetup) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("If you prefer terminal or have an existing Google Master Token:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    // Run CLI script button
                    Button {
                        runCLIScriptInTerminal()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 11))
                            Text("Launch CLI Setup Helper in Terminal")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Google Email")
                            .font(.system(size: 11, weight: .medium))
                        TextField("yourname@gmail.com", text: $manualEmail)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Master Token or oauth_token")
                            .font(.system(size: 11, weight: .medium))
                        SecureField("oauth2_4/... or oauth2rt_1/...", text: $manualToken)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Spacer()
                        Button("Connect with Token") {
                            connectWithManualToken()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(manualToken.trimmingCharacters(in: .whitespaces).isEmpty || isConnecting)
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("Advanced: Manual Setup & CLI Helper")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Embedded Browser Sign In View
    private var embeddedBrowserView: some View {
        VStack(spacing: 0) {
            // Browser Navigation Toolbar
            HStack(spacing: 12) {
                Button {
                    showEmbeddedBrowser = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Spacer()

                if isWebLoading || isConnecting {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(isConnecting ? "Connecting to Google Keep..." : "Sign in to Google")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button("Cancel") {
                    showEmbeddedBrowser = false
                }
                .font(.system(size: 12))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.thinMaterial)

            Divider()

            // WebKit View
            GoogleSignInWebView(
                isLoading: $isWebLoading,
                onTokenCaptured: { token, detectedEmail in
                    handleCapturedToken(token: token, email: detectedEmail)
                },
                onCancel: {
                    showEmbeddedBrowser = false
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Actions
    private func handleCapturedToken(token: String, email: String?) {
        isConnecting = true
        let resolvedEmail = email ?? (manualEmail.isEmpty ? "Google User" : manualEmail)

        Task {
            let (success, message) = await store.login(
                email: resolvedEmail,
                masterToken: token
            )
            isConnecting = false
            if success {
                showEmbeddedBrowser = false
                dismiss()
            } else {
                statusMessage = message
                showEmbeddedBrowser = false
            }
        }
    }

    private func connectWithManualToken() {
        let cleanEmail = manualEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToken = manualToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else { return }

        isConnecting = true
        statusMessage = nil

        Task {
            let (success, message) = await store.login(
                email: cleanEmail.isEmpty ? "Google Account" : cleanEmail,
                masterToken: cleanToken
            )
            isConnecting = false
            if success {
                dismiss()
            } else {
                statusMessage = message
            }
        }
    }

    private func runCLIScriptInTerminal() {
        let scriptPath = "/Users/madhuraj/Downloads/code/KNotes/scripts/get_master_token.py"
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(scriptPath)"
        end tell
        """
        if let scriptObject = NSAppleScript(source: appleScript) {
            var error: NSDictionary?
            scriptObject.executeAndReturnError(&error)
        }
    }
}
