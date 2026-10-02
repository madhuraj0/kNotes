import SwiftUI

public struct MainView: View {
    @StateObject private var store = NotesStore.shared
    @State private var columnVisibility = NavigationSplitViewVisibility.all

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
        .frame(minWidth: 800, minHeight: 500)
        .task {
            await store.initialize()
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
