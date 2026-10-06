import SwiftUI
import AppKit

public struct MenuBarQuickCaptureView: View {
    @ObservedObject var store = NotesStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @State private var title: String = ""
    @State private var text: String = ""
    @State private var isList: Bool = false
    @State private var selectedColor: String = "White"
    @State private var selectedTag: String? = "Quick Notes"
    @State private var isSaved: Bool = false
    @State private var hoveredNoteId: String? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                    Text("Quick Capture")
                        .font(.system(size: 13, weight: .bold))
                }

                Spacer()

                // Open full app button
                Button {
                    openMainWindow()
                } label: {
                    HStack(spacing: 4) {
                        Text("Open KNotes")
                            .font(.system(size: 10, weight: .medium))
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .help("Open main KNotes window")
            }
            .padding(.bottom, 2)

            // Title input
            TextField("Note title...", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, weight: .medium))

            // Body text / checklist input
            TextEditor(text: $text)
                .font(.system(size: 12))
                .frame(height: 90)
                .padding(4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.8)
                )

            // Options Bar: Type, Color, Tag
            HStack(spacing: 8) {
                // Checklist Toggle
                Button {
                    isList.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isList ? "checklist.checked" : "checklist")
                            .font(.system(size: 11))
                        Text(isList ? "List" : "Note")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isList ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    .foregroundColor(isList ? .accentColor : .primary)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                // Quick Color Picker Menu
                Menu {
                    ForEach(["White", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink", "Red", "Orange"], id: \.self) { c in
                        Button(c) {
                            selectedColor = c
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Note.swatchColor(for: selectedColor))
                            .frame(width: 8, height: 8)
                        Text(selectedColor)
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(5)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                // Save Note Button
                Button {
                    saveQuickNote()
                } label: {
                    HStack(spacing: 4) {
                        if isSaved {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("Saved")
                                .font(.system(size: 11, weight: .semibold))
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 12))
                            Text("Save")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty && text.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Divider()
                .padding(.vertical, 2)

            // Recent Notes Section
            if !store.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("RECENT NOTES")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    ForEach(store.notes.prefix(4)) { note in
                        let isHovered = hoveredNoteId == note.id
                        Button {
                            openMainWindow(noteId: note.id)
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Note.swatchColor(for: note.color))
                                    .frame(width: 7, height: 7)

                                Text(note.displayTitle)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Spacer()

                                Text(note.formattedDate)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(isHovered ? Color.primary.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            hoveredNoteId = hovering ? note.id : nil
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func openMainWindow(noteId: String? = nil) {
        if let noteId = noteId {
            store.selectedNoteId = noteId
        }

        NSApp.activate(ignoringOtherApps: true)

        let contentWindows = NSApp.windows.filter { window in
            !(window is NSPanel) &&
            !window.className.contains("StatusBar") &&
            window.canBecomeMain
        }

        if let visibleWindow = contentWindows.first(where: { $0.isVisible }) {
            if visibleWindow.isMiniaturized {
                visibleWindow.deminiaturize(nil)
            }
            visibleWindow.makeKeyAndOrderFront(nil)
            visibleWindow.orderFrontRegardless()
        } else if let closedWindow = contentWindows.first {
            closedWindow.makeKeyAndOrderFront(nil)
            closedWindow.orderFrontRegardless()
        } else {
            // Only open a new window scene if no content window exists
            openWindow(id: "main")
        }

        dismiss()
    }

    private func saveQuickNote() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedText.isEmpty else { return }

        var items: [ChecklistItem] = []
        if isList {
            let lines = trimmedText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            items = lines.map { ChecklistItem(text: $0, checked: false) }
        }

        var labels = ["Quick Notes"]
        if let sel = selectedTag, !labels.contains(sel) {
            labels.append(sel)
        }

        Task { @MainActor in
            do {
                let created = try await APIClient.shared.createNote(
                    title: trimmedTitle,
                    text: isList ? "" : trimmedText,
                    isList: isList,
                    items: items,
                    color: selectedColor,
                    pinned: false,
                    archived: false,
                    labels: labels
                )
                store.notes.insert(created, at: 0)
                store.selectedNoteId = created.id

                withAnimation {
                    isSaved = true
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
                title = ""
                text = ""
                withAnimation {
                    isSaved = false
                }
            } catch {
                print("Failed to save quick note: \(error)")
            }
        }
    }
}
