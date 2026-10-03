import SwiftUI

public struct NotesListView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isListFocused: Bool
    @State private var hoveredNoteId: String? = nil

    public init(store: NotesStore) {
        self.store = store
    }

    private var currentSectionTitle: String {
        store.sidebarSelection.title
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Folder Title & Note Count Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentSectionTitle)
                        .font(.system(size: 20, weight: .bold))

                    Text("\(store.notes.count) \(store.notes.count == 1 ? "Note" : "Notes")")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            // Integrated Liquid Glass Search Bar
            LiquidGlassSearchBar(store: store, text: $store.searchQuery)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)

            Divider()
                .opacity(0.6)

            // Notes list or Empty state
            if store.notes.isEmpty {
                if !store.searchQuery.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 34))
                            .foregroundColor(.secondary.opacity(0.4))

                        Text("No Results for \"\(store.searchQuery)\"")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Check your spelling or try different search terms.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Button("Clear Search") {
                            store.searchQuery = ""
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
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
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(store.notes) { note in
                                noteCard(for: note)
                                    .id(note.id)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .focusable()
                    .focusEffectDisabled()
                    .focused($isListFocused)
                    .onKeyPress(.downArrow) {
                        store.selectNextNote()
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        store.selectPreviousNote()
                        return .handled
                    }
                    .onKeyPress(.return) {
                        store.shouldFocusTitle = true
                        return .handled
                    }
                    .onChange(of: store.selectedNoteId) { _, newId in
                        if let newId = newId {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(newId, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 240, idealWidth: 280)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                accountTopBarItem
            }
        }
    }

    // MARK: - Account TopBar Item
    private var accountTopBarItem: some View {
        HStack(spacing: 8) {
            Button {
                store.showAccountSheet = true
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.status?.authenticated == true ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                        .shadow(color: (store.status?.authenticated == true ? Color.green : Color.orange).opacity(0.6), radius: 3)

                    Text(store.status?.authenticated == true ? (store.status?.email ?? "Google Keep") : "Local Mode")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .focusable(false)
            .help("Google Keep Account Settings (⌘,)")

            Button {
                store.syncNow()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(store.isSyncing ? 360 : 0))
                    .animation(store.isSyncing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: store.isSyncing)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .focusable(false)
            .help("Sync Now (⌘S)")
        }
    }

    // MARK: - Liquid Glass Note Card
    private func noteCard(for note: Note) -> some View {
        let isSelected = store.selectedNoteId == note.id
        let isHovered = hoveredNoteId == note.id

        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 6) {
                // Color indicator dot with subtle glow
                if note.color != "White" {
                    Circle()
                        .fill(note.accentTint)
                        .frame(width: 7, height: 7)
                        .shadow(color: note.accentTint.opacity(0.6), radius: 3)
                        .padding(.top, 4)
                }

                // Title - Always crisp primary contrast in both light and dark mode
                Text(note.displayTitle)
                    .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                // Pin indicator
                if note.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                        .shadow(color: Color.orange.opacity(0.4), radius: 2)
                }
            }

            // Date, snippet, and checklist icon
            HStack(spacing: 5) {
                if note.isList {
                    Image(systemName: "checklist")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .primary.opacity(0.9) : .secondary)
                }

                Text(note.formattedDate)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .primary.opacity(0.9) : .secondary)

                Text("•")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))

                Text(note.previewSnippet)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
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
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                        .foregroundColor(.secondary)
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
                        .background(Color.blue.opacity(0.12), in: Capsule())
                        .foregroundColor(.blue)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colorScheme == .dark ? Color.yellow.opacity(0.20) : Color.yellow.opacity(0.18))
                }
            } else if isHovered {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.02))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isSelected
                        ? LinearGradient(colors: [Color.yellow.opacity(0.65), Color.orange.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.primary.opacity(isHovered ? 0.12 : 0.05), Color.primary.opacity(isHovered ? 0.06 : 0.02)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isSelected ? 1.0 : 0.6
                )
        )
        .shadow(
            color: isSelected
                ? Color.yellow.opacity(colorScheme == .dark ? 0.14 : 0.09)
                : (isHovered ? Color.black.opacity(0.04) : Color.clear),
            radius: isSelected ? 8 : 4,
            x: 0,
            y: isSelected ? 2 : 1
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                hoveredNoteId = hovering ? note.id : nil
            }
        }
        .onTapGesture {
            store.selectedNoteId = note.id
            isListFocused = true
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
