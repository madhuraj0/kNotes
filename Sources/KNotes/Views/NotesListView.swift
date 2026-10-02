import SwiftUI

public struct NotesListView: View {
    @ObservedObject var store: NotesStore

    public init(store: NotesStore) {
        self.store = store
    }

    private var pinnedNotes: [Note] {
        store.notes.filter { $0.pinned }
    }

    private var regularNotes: [Note] {
        store.notes.filter { !$0.pinned }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))

                TextField("Search all notes...", text: $store.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !store.searchQuery.isEmpty {
                    Button {
                        store.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Header note count
            HStack {
                Text("\(store.notes.count) Notes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()

                Button {
                    store.createNote(isList: false)
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("New Note (⌘N)")
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            Divider()

            // Notes list
            if store.notes.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "note.text")
                        .font(.system(size: 38))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No Notes Found")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Button("Create Note") {
                        store.createNote(isList: false)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(selection: $store.selectedNoteId) {
                        if !pinnedNotes.isEmpty {
                            Section(header: Text("PINNED").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)) {
                                ForEach(pinnedNotes) { note in
                                    noteRow(for: note)
                                        .tag(note.id)
                                }
                            }
                        }

                        if !regularNotes.isEmpty {
                            Section(header: Text(!pinnedNotes.isEmpty ? "NOTES" : "").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)) {
                                ForEach(regularNotes) { note in
                                    noteRow(for: note)
                                        .tag(note.id)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
        }
        .frame(minWidth: 230, idealWidth: 280)
    }

    private func noteRow(for note: Note) -> some View {
        let isSelected = store.selectedNoteId == note.id

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                // Color indicator dot
                if note.color != "White" {
                    Circle()
                        .fill(note.accentTint)
                        .frame(width: 7, height: 7)
                        .padding(.top, 4)
                }

                // Title
                Text(note.displayTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)

                Spacer()

                // Pin indicator
                if note.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .orange)
                }
            }

            // Date and snippet
            HStack(spacing: 5) {
                Text(note.formattedDate)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)

                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white.opacity(0.6) : .secondary.opacity(0.6))

                Text(note.previewSnippet)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.75) : .secondary)
                    .lineLimit(1)
            }

            // Labels / Tag pills
            if !note.labels.isEmpty {
                HStack(spacing: 4) {
                    ForEach(note.labels, id: \.self) { labelName in
                        HStack(spacing: 2) {
                            Text("#")
                                .font(.system(size: 9, weight: .bold))
                            Text(labelName)
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.12))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .cornerRadius(6)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectedNoteId = note.id
        }
        .contextMenu {
            Button {
                store.togglePin(note: note)
            } label: {
                Label(note.pinned ? "Unpin Note" : "Pin Note", systemImage: note.pinned ? "pin.slash" : "pin")
            }

            Menu("Note Color") {
                ForEach(["White", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink", "Red", "Orange", "Gray"], id: \.self) { col in
                    Button(col) {
                        store.changeColor(note: note, color: col)
                    }
                }
            }

            Menu("Manage Tags") {
                ForEach(store.labels) { lbl in
                    Button {
                        store.toggleLabel(note: note, labelName: lbl.name)
                    } label: {
                        HStack {
                            Text(lbl.name)
                            if note.labels.contains(lbl.name) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Button {
                store.toggleNoteType(note: note)
            } label: {
                Label(note.isList ? "Convert to Text Note" : "Convert to Checklist", systemImage: note.isList ? "text.alignleft" : "checklist")
            }

            Divider()

            Button(role: .destructive) {
                store.deleteNote(note: note)
            } label: {
                Label("Move to Trash", systemImage: "trash")
            }
        }
    }
}
