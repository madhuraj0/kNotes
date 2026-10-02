import SwiftUI

public struct NewLabelSheetView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.dismiss) private var dismiss

    @State private var labelName: String = ""
    @State private var isSubmitting: Bool = false

    public init(store: NotesStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("New Tag")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Tag Name")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("e.g. Travel, Ideas, Receipts", text: $labelName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        submit()
                    }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(labelName.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func submit() {
        let trimmed = labelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        Task {
            _ = await store.createLabel(name: trimmed)
            isSubmitting = false
            dismiss()
        }
    }
}
