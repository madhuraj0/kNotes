import SwiftUI

public struct NoteEditorView: View {
    @ObservedObject var store: NotesStore

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var editorFocus: EditorFocusField?

    enum EditorFocusField: Hashable {
        case title
        case body
    }

    @State private var noteTitle: String = ""
    @State private var noteText: String = ""
    @State private var noteItems: [ChecklistItem] = []
    @State private var showColorPopover: Bool = false
    @State private var showSharePopover: Bool = false
    @State private var isMarkdownPreview: Bool = false

    public init(store: NotesStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            if let note = store.selectedNote {
                VStack(spacing: 0) {
                    // Header Date
                    Text(note.headerDate)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.top, 14)
                        .padding(.bottom, 6)

                    // Note Content ScrollView
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            // Large Title Field
                            TextField("Title", text: $noteTitle)
                                .textFieldStyle(.plain)
                                .font(.system(size: 26, weight: .bold))
                                .padding(.horizontal, 24)
                                .focused($editorFocus, equals: .title)
                                .onChange(of: noteTitle) { _, newValue in
                                    store.updateSelectedNoteLocally(title: newValue)
                                }
                                .onSubmit {
                                    if !note.isList {
                                        editorFocus = .body
                                    }
                                }

                            // Tags and Collaborators Pills Row
                            if !note.labels.isEmpty || !note.collaborators.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        // Quick Note indicator badge if applicable
                                        if note.isQuickNote {
                                            HStack(spacing: 4) {
                                                Image(systemName: "bolt.fill")
                                                    .font(.system(size: 9))
                                                Text("Quick Note")
                                                    .font(.system(size: 11, weight: .medium))
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.yellow.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .cornerRadius(6)
                                        }

                                        // Labels
                                        ForEach(note.labels, id: \.self) { labelName in
                                            HStack(spacing: 3) {
                                                Text("#")
                                                    .font(.system(size: 10, weight: .bold))
                                                Text(labelName)
                                                    .font(.system(size: 11))
                                                Button {
                                                    store.toggleLabel(note: note, labelName: labelName)
                                                } label: {
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 8))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.secondary.opacity(0.12))
                                            .foregroundColor(.secondary)
                                            .cornerRadius(6)
                                        }

                                        // Collaborator Pills
                                        ForEach(note.collaborators, id: \.self) { email in
                                            HStack(spacing: 4) {
                                                Image(systemName: "person.crop.circle")
                                                    .font(.system(size: 10))
                                                Text(email)
                                                    .font(.system(size: 11))
                                                Button {
                                                    store.removeCollaborator(note: note, email: email)
                                                } label: {
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 8))
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.accentColor.opacity(0.12))
                                            .foregroundColor(.accentColor)
                                            .cornerRadius(6)
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }

                            // Body: Checklist or TextEditor
                            if note.isList {
                                ChecklistView(
                                    items: Binding(
                                        get: { noteItems },
                                        set: { newItems in
                                            noteItems = newItems
                                            store.updateSelectedNoteLocally(items: newItems)
                                        }
                                    ),
                                    onUpdate: {
                                        store.updateSelectedNoteLocally(items: noteItems)
                                    }
                                )
                                .padding(.horizontal, 24)
                            } else {
                                if isMarkdownPreview {
                                    MarkdownPreviewView(markdownText: noteText, noteColor: note.swiftUIColor)
                                        .frame(minHeight: 400)
                                } else {
                                    TextEditor(text: $noteText)
                                        .font(.system(size: 15))
                                        .lineSpacing(4)
                                        .padding(.horizontal, 20)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 400)
                                        .focused($editorFocus, equals: .body)
                                        .onChange(of: noteText) { _, newText in
                                            store.updateSelectedNoteLocally(text: newText)
                                        }
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
                .background(note.dynamicBackgroundColor(isDark: colorScheme == .dark).opacity(colorScheme == .dark ? 0.45 : 0.35))
                .onAppear {
                    loadNoteData(note)
                }
                .onChange(of: store.selectedNoteId) { _, _ in
                    if let n = store.selectedNote {
                        loadNoteData(n)
                    }
                }
                .toolbar {
                    editorToolbar(for: note)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No Note Selected")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Button("New Note") {
                        store.createNote(isList: false)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .toolbar {
                    editorToolbar(for: nil)
                }
            }
        }
    }

    private func loadNoteData(_ note: Note) {
        self.noteTitle = note.title
        self.noteText = note.text
        self.noteItems = note.items
    }

    @ToolbarContentBuilder
    private func editorToolbar(for note: Note?) -> some ToolbarContent {
        // 1. Left-aligned above the editor line (placement: .navigation)
        ToolbarItemGroup(placement: .navigation) {
            Button {
                store.createNote(isList: false)
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .medium))
            }
            .help("New Note (⌘N)")

            Button {
                store.createNote(isList: true)
            } label: {
                Image(systemName: "checklist")
                    .font(.system(size: 13, weight: .medium))
            }
            .help("New Checklist (⇧⌘N)")
        }

        // 2. Principal: Color Palette in the middle of the top bar
        ToolbarItem(placement: .principal) {
            if let note = note {
                Button {
                    showColorPopover.toggle()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 13))
                            .foregroundColor(note.accentTint)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("Note Color")
                .popover(isPresented: $showColorPopover, arrowEdge: .bottom) {
                    ColorPalettePickerView(selectedColor: note.color) { newColor in
                        store.changeColor(note: note, color: newColor)
                        showColorPopover = false
                    }
                }
            }
        }

        // 3. Right side / Primary actions of toolbar
        ToolbarItemGroup(placement: .primaryAction) {
            if let note = note {
                // Toggle Checklist / Text Mode
                Button {
                    store.toggleNoteType(note: note)
                } label: {
                    Image(systemName: note.isList ? "text.alignleft" : "checklist")
                        .foregroundColor(note.isList ? .accentColor : .secondary)
                }
                .help(note.isList ? "Convert to Plain Text" : "Convert to Checklist")

                // Rich Markdown Preview Toggle (for text notes)
                if !note.isList {
                    Button {
                        isMarkdownPreview.toggle()
                    } label: {
                        Image(systemName: isMarkdownPreview ? "pencil" : "eye")
                            .foregroundColor(isMarkdownPreview ? .accentColor : .secondary)
                    }
                    .help(isMarkdownPreview ? "Edit Raw Markdown" : "Rich Markdown Preview")
                }

                // Tags Menu
                Menu {
                    ForEach(store.labels) { label in
                        Button {
                            store.toggleLabel(note: note, labelName: label.name)
                        } label: {
                            HStack {
                                Text(label.name)
                                if note.labels.contains(label.name) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("New Tag...") {
                        store.showNewLabelSheet = true
                    }
                } label: {
                    Image(systemName: "tag")
                }
                .help("Tags")

                // Google Keep Collaborators Popover
                Button {
                    showSharePopover.toggle()
                } label: {
                    Image(systemName: note.collaborators.isEmpty ? "person.crop.circle.badge.plus" : "person.2.fill")
                        .foregroundColor(!note.collaborators.isEmpty ? .accentColor : .secondary)
                }
                .help("Google Keep Collaborators")
                .popover(isPresented: $showSharePopover, arrowEdge: .bottom) {
                    CollaboratorsPopoverView(note: note, store: store, isPresented: $showSharePopover)
                }

                // Native macOS Share Sheet
                ShareLink(
                    item: note.shareText,
                    subject: Text(note.displayTitle),
                    message: Text(note.previewSnippet)
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Share Note (macOS Share Sheet)")

                // Archive / Unarchive
                Button {
                    store.toggleArchive(note: note)
                } label: {
                    Image(systemName: note.archived ? "archivebox.fill" : "archivebox")
                        .foregroundColor(note.archived ? .accentColor : .secondary)
                }
                .help(note.archived ? "Unarchive Note" : "Archive Note")

                // Pin / Unpin
                Button {
                    store.togglePin(note: note)
                } label: {
                    Image(systemName: note.pinned ? "pin.fill" : "pin")
                        .foregroundColor(note.pinned ? .orange : .secondary)
                }
                .help(note.pinned ? "Unpin Note" : "Pin Note")

                // Delete Note
                Button {
                    store.deleteNote(note: note)
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete Note (⌘⌫)")
            }

            // Continuously Expanded Liquid Glass Search Bar
            LiquidGlassSearchBar(text: $store.searchQuery)
        }
    }
}

// MARK: - Color Palette Popover View
struct ColorPalettePickerView: View {
    let selectedColor: String
    let onSelect: (String) -> Void

    let colors: [String] = [
        "White", "Yellow", "Green", "Teal",
        "Blue", "DarkBlue", "Purple", "Pink",
        "Brown", "Gray", "Red", "Orange"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOTE COLOR")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(26), spacing: 8), count: 6), spacing: 8) {
                ForEach(colors, id: \.self) { colorName in
                    Button {
                        onSelect(colorName)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Note.swatchColor(for: colorName))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.secondary.opacity(colorName == "White" ? 0.35 : 0.15), lineWidth: 1)
                                )

                            if selectedColor == colorName {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(colorName == "White" || colorName == "Yellow" ? .black : .white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(colorName)
                }
            }
        }
        .padding(12)
        .frame(width: 216)
    }
}

// MARK: - Collaborators Popover View
struct CollaboratorsPopoverView: View {
    let note: Note
    @ObservedObject var store: NotesStore
    @Binding var isPresented: Bool
    @State private var newCollaboratorEmail: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.accentColor)
                Text("Share Note")
                    .font(.headline)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("Share this note with Google accounts. They will see edits in their Google Keep.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Collaborators list
            if note.collaborators.isEmpty {
                Text("No collaborators added yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(note.collaborators, id: \.self) { email in
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.secondary)
                            Text(email)
                                .font(.system(size: 12))
                                .lineLimit(1)
                            Spacer()
                            Button {
                                store.removeCollaborator(note: note, email: email)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Remove collaborator")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Divider()

            HStack {
                TextField("Add Google email...", text: $newCollaboratorEmail)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addCollaborator()
                    }

                Button("Add") {
                    addCollaborator()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newCollaboratorEmail.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private func addCollaborator() {
        let trimmed = newCollaboratorEmail.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        store.addCollaborator(note: note, email: trimmed)
        newCollaboratorEmail = ""
    }
}
