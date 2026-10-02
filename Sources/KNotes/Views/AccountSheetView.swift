import SwiftUI

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
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 36))
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Google Keep Sync")
                        .font(.system(size: 18, weight: .bold))
                    Text("Sync notes bidirectionally with Google Keep")
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
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sign in with Google")
                        .font(.system(size: 14, weight: .semibold))

                    Text("If 2-Step Verification is active, generate a Google App Password from: Google Account > Security > App passwords.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color.yellow.opacity(0.12))
                        .cornerRadius(6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Google Email")
                            .font(.system(size: 11, weight: .medium))
                        TextField("name@gmail.com", text: $email)
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
                            SecureField("16-character App Password", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Master Token (oauth)")
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

                    if let msg = loginMessage {
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
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
                        .disabled(email.isEmpty || (password.isEmpty && masterToken.isEmpty) || isLoggingIn)
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.top, 8)
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 440, height: 380)
    }

    private func performLogin() {
        guard !email.isEmpty else { return }
        isLoggingIn = true
        loginMessage = nil

        Task {
            let (success, message) = await store.login(
                email: email,
                password: isUsingToken ? nil : password,
                masterToken: isUsingToken ? masterToken : nil
            )
            isLoggingIn = false
            if success {
                dismiss()
            } else {
                loginMessage = message
            }
        }
    }
}
