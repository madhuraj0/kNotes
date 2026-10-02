import SwiftUI
import AppKit

@main
struct KNotesApp: App {
    @StateObject private var store = NotesStore.shared

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
                .onOpenURL { url in
                    handleIncomingURL(url)
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
                Button("Google Keep Account Settings...") {
                    store.showAccountSheet = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        MenuBarExtra("KNotes", systemImage: "note.text.badge.plus") {
            MenuBarQuickCaptureView()
        }
        .menuBarExtraStyle(.window)
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "knotes" else { return }

        if url.host == "note", let noteId = url.pathComponents.dropFirst().first {
            store.selectedNoteId = noteId
        } else if url.host == "new" {
            store.createNote(isList: false)
        } else if url.host == "sync" {
            store.syncNow()
        }
    }
}
