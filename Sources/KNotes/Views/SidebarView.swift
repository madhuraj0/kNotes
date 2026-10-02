import SwiftUI

public struct SidebarView: View {
    @ObservedObject var store: NotesStore

    public init(store: NotesStore) {
        self.store = store
    }

    public var body: some View {
        List(selection: $store.sidebarSelection) {
            Section("Quick Access") {
                ForEach(Folder.allCases) { folder in
                    HStack(spacing: 10) {
                        Image(systemName: folder.iconName)
                            .foregroundColor(folder.iconColor)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 20)

                        Text(folder.title)
                            .font(.system(size: 13, weight: .regular))

                        Spacer()

                        if let count = countForFolder(folder), count > 0 {
                            Text("\(count)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(8)
                        }
                    }
                    .tag(SidebarItem.folder(folder))
                    .contentShape(Rectangle())
                }
            }

            Section {
                if store.labels.isEmpty {
                    Text("No tags yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(store.labels) { label in
                        HStack(spacing: 8) {
                            Image(systemName: "number")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.accentColor)
                                .frame(width: 20)

                            Text(label.name)
                                .font(.system(size: 13))

                            Spacer()

                            let count = countForLabel(label.name)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.12))
                                    .cornerRadius(8)
                            }
                        }
                        .tag(SidebarItem.tag(label.name))
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button(role: .destructive) {
                                Task {
                                    await store.deleteLabel(id: label.id)
                                }
                            } label: {
                                Label("Delete Tag", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Tags")
                    Spacer()
                    Button {
                        store.showNewLabelSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add New Tag (⌘T)")
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func countForFolder(_ folder: Folder) -> Int? {
        guard let s = store.status else { return nil }
        switch folder {
        case .all: return s.totalNotes
        case .quick: return s.quickNotes
        case .pinned: return s.pinnedNotes
        case .archived: return s.archivedNotes
        case .trash: return s.trashNotes
        }
    }

    private func countForLabel(_ labelName: String) -> Int {
        store.notes.filter { $0.labels.contains(labelName) }.count
    }
}
