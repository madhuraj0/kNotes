import SwiftUI
import AppKit
import CoreSpotlight

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        if userActivity.activityType == CSSearchableItemActionType {
            if let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                let noteId = identifier.replacingOccurrences(of: "knotes.note.", with: "")
                Task { @MainActor in
                    NotesStore.shared.selectedNoteId = noteId
                }
                return true
            }
        }
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where !(window is NSPanel) && !window.className.contains("StatusBar") {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}

@main
struct KNotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = NotesStore.shared
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra: Bool = true

    var body: some Scene {
        WindowGroup(id: "main") {
            MainView()
                .environmentObject(store)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                    if let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                        let noteId = identifier.replacingOccurrences(of: "knotes.note.", with: "")
                        store.selectedNoteId = noteId
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    store.createNote(isList: false)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Checklist") {
                    store.createNote(isList: true)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("New Tag...") {
                    store.showNewLabelSheet = true
                }
                .keyboardShortcut("t", modifiers: .command)

                Divider()

                Button("Sync with Google Keep") {
                    store.syncNow()
                }
                .keyboardShortcut("s", modifiers: .command)
            }

            CommandGroup(replacing: .appSettings) {
                Button("kNotes Account Settings...") {
                    store.showAccountSheet = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(after: .pasteboard) {
                Divider()

                Button(store.selectedNote?.trashed == true ? "Delete Note Permanently" : "Move Note to Trash") {
                    if let note = store.selectedNote {
                        store.deleteNote(note: note)
                    }
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(store.selectedNote == nil)
            }

            CommandGroup(after: .textEditing) {
                Button("Find in Notes...") {
                    store.shouldFocusSearch = true
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            CommandMenu("Note") {
                Button(store.selectedNote?.pinned == true ? "Unpin Note" : "Pin Note") {
                    if let note = store.selectedNote {
                        store.togglePin(note: note)
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(store.selectedNote == nil)

                Button(store.selectedNote?.archived == true ? "Unarchive Note" : "Archive Note") {
                    if let note = store.selectedNote {
                        store.toggleArchive(note: note)
                    }
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(store.selectedNote == nil)

                Divider()

                Button("Toggle Markdown Preview") {
                    store.shouldToggleMarkdownPreview = true
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(store.selectedNote == nil || store.selectedNote?.isList == true)

                Button(store.selectedNote?.isList == true ? "Convert to Plain Text" : "Convert to Checklist") {
                    if let note = store.selectedNote {
                        store.toggleNoteType(note: note)
                    }
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .disabled(store.selectedNote == nil)

                Divider()

                Button("Change Note Color...") {
                    store.shouldShowColorPicker = true
                }
                .keyboardShortcut("c", modifiers: [.control, .command])
                .disabled(store.selectedNote == nil)

                Menu("Note Color") {
                    ForEach(["White", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink", "Red", "Orange", "Gray"], id: \.self) { colorName in
                        Button(colorName) {
                            if let note = store.selectedNote {
                                store.changeColor(note: note, color: colorName)
                            }
                        }
                    }
                }
                .disabled(store.selectedNote == nil)
            }

            CommandMenu("Go") {
                Button("All Notes") {
                    store.sidebarSelection = .folder(.all)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Quick Notes") {
                    store.sidebarSelection = .folder(.quick)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Pinned") {
                    store.sidebarSelection = .folder(.pinned)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Archive") {
                    store.sidebarSelection = .folder(.archived)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Recently Deleted") {
                    store.sidebarSelection = .folder(.trash)
                }
                .keyboardShortcut("5", modifiers: .command)

                Divider()

                Button("Next Note") {
                    store.selectNextNote()
                }
                .keyboardShortcut(.downArrow, modifiers: .option)
                .disabled(store.notes.isEmpty)

                Button("Previous Note") {
                    store.selectPreviousNote()
                }
                .keyboardShortcut(.upArrow, modifiers: .option)
                .disabled(store.notes.isEmpty)

                Button("Next Note in List") {
                    store.selectNextNote()
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(store.notes.isEmpty)

                Button("Previous Note in List") {
                    store.selectPreviousNote()
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(store.notes.isEmpty)
            }

            CommandGroup(after: .toolbar) {
                Divider()
                Toggle("Show Menu Bar Icon", isOn: $showMenuBarExtra)
            }
        }

        MenuBarExtra(isInserted: $showMenuBarExtra) {
            MenuBarQuickCaptureView()
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .menuBarExtraStyle(.window)
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "knotes" else { return }

        if url.host == "note", let noteId = url.pathComponents.dropFirst().first {
            store.selectedNoteId = noteId
            NSApp.activate(ignoringOtherApps: true)
        } else if url.host == "new" {
            store.createNote(isList: false)
            NSApp.activate(ignoringOtherApps: true)
        } else if url.host == "sync" {
            store.syncNow()
        }
    }
}
