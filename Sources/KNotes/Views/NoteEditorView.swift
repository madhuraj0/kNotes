import SwiftUI

public struct NoteEditorView: View {
    @ObservedObject var store: NotesStore

    @State private var noteTitle: String = ""
    @State private var noteText: String = ""
    @State private var noteItems: [ChecklistItem] = []

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
                                .onChange(of: noteTitle) { _, newValue in
                                    store.updateSelectedNoteLocally(title: newValue)
                                }

                            // Tag Pills Row
                            if !note.labels.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
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
                                TextEditor(text: $noteText)
                                    .font(.system(size: 15))
                                    .lineSpacing(4)
                                    .padding(.horizontal, 20)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 400)
                                    .onChange(of: noteText) { _, newText in
                                        store.updateSelectedNoteLocally(text: newText)
                                    }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
                .background(note.swiftUIColor.opacity(0.3))
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
            }
        }
    }

    private func loadNoteData(_ note: Note) {
        self.noteTitle = note.title
        self.noteText = note.text
        self.noteItems = note.items
    }

    @ToolbarContentBuilder
    private func editorToolbar(for note: Note) -> some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Delete Note
            Button {
                store.deleteNote(note: note)
            } label: {
                Image(systemName: "trash")
            }
            .help("Delete Note (⌘⌫)")

            // Pin / Unpin
            Button {
                store.togglePin(note: note)
            } label: {
                Image(systemName: note.pinned ? "pin.fill" : "pin")
                    .foregroundColor(note.pinned ? .orange : .secondary)
            }
            .help(note.pinned ? "Unpin Note" : "Pin Note")

            // Toggle Checklist / Text Mode
            Button {
                store.toggleNoteType(note: note)
            } label: {
                Image(systemName: note.isList ? "checklist.checked" : "checklist")
                    .foregroundColor(note.isList ? .accentColor : .secondary)
            }
            .help(note.isList ? "Convert to Text Note" : "Convert to Checklist")

            // Color Palette Menu
            Menu {
                ForEach(["White", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink", "Red", "Orange", "Gray"], id: \.self) { colorName in
                    Button {
                        store.changeColor(note: note, color: colorName)
                    } label: {
                        HStack {
                            Text(colorName)
                            if note.color == colorName {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "circle.circle")
                    .foregroundColor(note.accentTint)
            }
            .help("Change Color")

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
            .help("Add Tag")

            // Manual Sync Button
            Button {
                store.syncNow()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
            .help("Sync with Google Keep")

            // New Note Button
            Button {
                store.createNote(isList: false)
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .help("New Note (⌘N)")
        }
    }
}
