import SwiftUI
import AppKit

public struct AccountSheetView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var masterToken: String = ""
    @State private var isUsingToken: Bool = false
    @State private var loginMessage: String? = nil
    @State private var isLoggingIn: Bool = false

    public init(store: NotesStore) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "note.text.badge.plus")
                        .font(.system(size: 34))
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
                    // Connected state
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
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
                        .padding(12)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 6) {
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
                        .padding(10)
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
                    }
                } else {
                    // Sign in form
                    VStack(alignment: .leading, spacing: 14) {
                        // Guide Callout
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                Text("How to Create a Google App Password")
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Button {
                                    if let url = URL(string: "https://myaccount.google.com/apppasswords") {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 3) {
                                        Text("Open Google Security")
                                        Image(systemName: "arrow.up.right.square")
                                    }
                                    .font(.system(size: 11))
                                    .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }

                            Text("1. Visit myaccount.google.com/apppasswords (ensure 2-Step Verification is ON).\n2. Under 'App name', enter KNotes and click Create.\n3. Copy the 16-character code and paste it below.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(Color.yellow.opacity(0.12))
                        .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Google Email")
                                .font(.system(size: 11, weight: .medium))
                            TextField("yourname@gmail.com", text: $email)
                                .textFieldStyle(.roundedBorder)
                        }

                        if !isUsingToken {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("App Password")
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    Button("Use Master Token instead") {
                                        isUsingToken = true
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10))
                                    .foregroundColor(.accentColor)
                                }
                                SecureField("16-character App Password (e.g. abcd efgh ijkl mnop)", text: $password)
                                    .textFieldStyle(.roundedBorder)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Master Token (gpsoauth)")
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    Button("Use App Password instead") {
                                        isUsingToken = false
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 10))
                                    .foregroundColor(.accentColor)
                                }
                                SecureField("oauth2_4/...", text: $masterToken)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }

                        // Error / status message callout (Multiline & Non-trimmed)
                        if let msg = loginMessage {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 13))
                                    .padding(.top, 2)

                                Text(friendlyMessage(from: msg))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.red)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }

                        HStack {
                            Spacer()
                            Button("Cancel") {
                                dismiss()
                            }
                            .keyboardShortcut(.cancelAction)

                            Button {
                                performLogin()
                            } label: {
                                if isLoggingIn {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Connect Account")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || (password.isEmpty && masterToken.isEmpty) || isLoggingIn)
                            .keyboardShortcut(.defaultAction)
                        }
                        .padding(.top, 6)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .frame(width: 480)
        .frame(minHeight: 460, maxHeight: 600)
    }

    private func performLogin() {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPw = password.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
        let cleanToken = masterToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanEmail.isEmpty else { return }
        isLoggingIn = true
        loginMessage = nil

        Task {
            let (success, message) = await store.login(
                email: cleanEmail,
                password: isUsingToken ? nil : cleanPw,
                masterToken: isUsingToken ? cleanToken : nil
            )
            isLoggingIn = false
            if success {
                dismiss()
            } else {
                loginMessage = message
            }
        }
    }

    private func friendlyMessage(from raw: String) -> String {
        if raw.contains("NeedsBrowser") || raw.contains("BadAuthentication") {
            return "Authentication failed: Google requires an App Password when 2-Step Verification is enabled. Please generate a 16-character App Password using the link above and try again."
        }
        return raw
    }
}
