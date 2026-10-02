import SwiftUI

public struct WidgetPreviewView: View {
    @ObservedObject var store = NotesStore.shared
    @State private var quickText: String = ""

    public init() {}

    private var pinnedNotes: [Note] {
        store.notes.filter { $0.pinned }
    }

    private var latestChecklist: Note? {
        store.notes.first(where: { $0.isList && !$0.items.isEmpty })
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Widget Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.orange)
                    Text("KNotes")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(store.status?.authenticated == true ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(store.status?.authenticated == true ? "Synced" : "Local")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            // Checklist or Pinned Note Preview
            if let listNote = latestChecklist {
                VStack(alignment: .leading, spacing: 6) {
                    Text(listNote.displayTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    ForEach(listNote.items.prefix(4)) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 11))
                                .foregroundColor(item.checked ? .accentColor : .secondary)

                            Text(item.text.isEmpty ? "Checklist item" : item.text)
                                .font(.system(size: 11))
                                .strikethrough(item.checked, color: .secondary)
                                .foregroundColor(item.checked ? .secondary : .primary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(12)
            } else if let pinned = pinnedNotes.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pinned.displayTitle)
                        .font(.system(size: 12, weight: .bold))
                    Text(pinned.previewSnippet)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(12)
            }

            // Quick Capture field
            HStack(spacing: 6) {
                TextField("Quick note...", text: $quickText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                    .onSubmit {
                        commitQuickNote()
                    }

                Button {
                    commitQuickNote()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(quickText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
        .frame(width: 280)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    private func commitQuickNote() {
        let trimmed = quickText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            _ = try? await APIClient.shared.createNote(
                title: trimmed,
                text: "",
                isList: false,
                items: [],
                color: "White",
                pinned: false,
                archived: false,
                labels: ["Quick Notes"]
            )
            await store.fetchNotes()
            quickText = ""
        }
    }
}
