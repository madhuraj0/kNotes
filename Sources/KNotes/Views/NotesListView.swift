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

    private var currentSectionTitle: String {
        store.sidebarSelection.title
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Account & Sync Bar (Moved to top of notes list as requested)
            accountStatusBar
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // Folder Title & Note Count Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentSectionTitle)
                        .font(.system(size: 20, weight: .bold))

                    Text("\(store.notes.count) Notes")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        store.createNote(isList: true)
                    } label: {
                        Image(systemName: "checklist")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("New Checklist (⇧⌘N)")

                    Button {
                        store.createNote(isList: false)
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("New Note (⌘N)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Notes list or Empty state
            if store.notes.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: emptyStateIcon)
                        .font(.system(size: 38))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(emptyStateText)
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
                List(selection: $store.selectedNoteId) {
                    if !pinnedNotes.isEmpty && store.selectedFolder != .pinned {
                        Section(header: Text("PINNED").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)) {
                            ForEach(pinnedNotes) { note in
                                noteRow(for: note)
                                    .tag(note.id)
                            }
                        }
                    }

                    Section(header: Text((!pinnedNotes.isEmpty && store.selectedFolder != .pinned) ? "NOTES" : "").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)) {
                        ForEach(store.selectedFolder == .pinned ? pinnedNotes : regularNotes) { note in
                            noteRow(for: note)
                                .tag(note.id)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 240, idealWidth: 280)
    }

    // MARK: - Account Status Bar
    private var accountStatusBar: some View {
        HStack(spacing: 8) {
            Button {
                store.showAccountSheet = true
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.status?.authenticated == true ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(store.status?.authenticated == true ? (store.status?.email ?? "Google Keep") : "Local Mode")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .help("Google Keep Account Settings (⌘,)")

            Spacer()

            Button {
                store.syncNow()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(store.isSyncing ? 360 : 0))
                    .animation(store.isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: store.isSyncing)
            }
            .buttonStyle(.plain)
            .help("Sync Now (⌘S)")
        }
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

            // Date, snippet, and checklist icon
            HStack(spacing: 5) {
                if note.isList {
                    Image(systemName: "checklist")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                }

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

            // Labels & Collaborators
            if !note.labels.isEmpty || !note.collaborators.isEmpty {
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

                    if !note.collaborators.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 8))
                            Text("\(note.collaborators.count)")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.12))
                        .foregroundColor(isSelected ? .white : .blue)
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

            Button {
                store.toggleArchive(note: note)
            } label: {
                Label(note.archived ? "Unarchive Note" : "Archive Note", systemImage: "archivebox")
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

            if note.trashed {
                Button("Restore Note") {
                    store.restoreNote(note: note)
                }
                Button(role: .destructive) {
                    store.deleteNote(note: note)
                } label: {
                    Label("Delete Permanently", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    store.deleteNote(note: note)
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
            }
        }
    }

    private var emptyStateIcon: String {
        switch store.selectedFolder {
        case .all: return "note.text"
        case .quick: return "bolt.fill"
        case .pinned: return "pin.fill"
        case .archived: return "archivebox.fill"
        case .trash: return "trash.fill"
        }
    }

    private var emptyStateText: String {
        switch store.selectedFolder {
        case .all: return "No Notes"
        case .quick: return "No Quick Notes"
        case .pinned: return "No Pinned Notes"
        case .archived: return "Archive is Empty"
        case .trash: return "Recently Deleted is Empty"
        }
    }
}
