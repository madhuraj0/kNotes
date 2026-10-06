import SwiftUI
import AppKit

public struct AccountSheetView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.dismiss) private var dismiss

    @State private var showEmbeddedBrowser: Bool = false
    @State private var isWebLoading: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isConnecting: Bool = false
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra: Bool = true

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
        .frame(minHeight: showEmbeddedBrowser ? 600 : 440, maxHeight: 660)
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
                        Text("Settings & Account")
                            .font(.system(size: 18, weight: .bold))
                        Text("Manage your Google Keep sync and app preferences")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .focusable(false)
                    .help("Close (Esc)")
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.top, 4)

                Divider()

                if store.status?.authenticated == true {
                    connectedAccountView
                } else {
                    signInOptionsView
                }

                Divider()

                preferencesView

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

            Button(role: .destructive) {
                Task {
                    await store.logout()
                }
            } label: {
                Text("Sign Out")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
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
                Text("Sign in directly with your Google account. KNotes will automatically establish a secure connection and sync your Google Keep notes bidirectionally.")
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
        }
    }

    // MARK: - Preferences
    private var preferencesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General Preferences")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Toggle(isOn: $showMenuBarExtra) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Menu Bar Icon")
                        .font(.system(size: 13, weight: .medium))
                    Text("Quick Capture notes and view recent items directly from the macOS menu bar")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(10)
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
                .focusEffectDisabled()
                .focusable(false)

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
                .focusEffectDisabled()
                .focusable(false)
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
        let resolvedEmail = email ?? ""

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
}
