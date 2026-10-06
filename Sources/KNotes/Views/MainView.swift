import SwiftUI

public struct MainView: View {
    @EnvironmentObject private var store: NotesStore
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @SceneStorage("savedSelectedNoteId") private var savedSelectedNoteId: String = ""
    @SceneStorage("savedSidebarFolder") private var savedSidebarFolder: String = "all"

    public init() {}

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
        } content: {
            NotesListView(store: store)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            NoteEditorView(store: store)
        }
        .navigationSplitViewStyle(.balanced)
        .accentColor(Color(red: 0.95, green: 0.72, blue: 0.15))
        .frame(minWidth: 800, minHeight: 500)
        .background {
            Button("") {
                if let note = store.selectedNote {
                    store.deleteNote(note: note)
                }
            }
            .keyboardShortcut(.deleteForward, modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .disabled(store.selectedNote == nil)
        }
        .task {
            if !savedSidebarFolder.isEmpty, let folder = Folder(rawValue: savedSidebarFolder) {
                store.sidebarSelection = .folder(folder)
            }
            await store.initialize()
            if !savedSelectedNoteId.isEmpty && store.notes.contains(where: { $0.id == savedSelectedNoteId }) {
                store.selectedNoteId = savedSelectedNoteId
            }
        }
        .onChange(of: store.selectedNoteId) { _, newId in
            if let newId = newId {
                savedSelectedNoteId = newId
            }
        }
        .onChange(of: store.selectedFolder) { _, newFolder in
            savedSidebarFolder = newFolder.rawValue
        }
        .sheet(isPresented: $store.showAccountSheet) {
            AccountSheetView(store: store)
        }
        .sheet(isPresented: $store.showNewLabelSheet) {
            NewLabelSheetView(store: store)
        }
        .alert("Notice", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
