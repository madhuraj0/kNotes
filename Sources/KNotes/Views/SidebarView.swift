import SwiftUI

public struct SidebarView: View {
    @ObservedObject var store: NotesStore

    public init(store: NotesStore) {
        self.store = store
    }

    public var body: some View {
        List {
            Section("Quick Access") {
                ForEach(Folder.allCases) { folder in
                    NavigationLink(
                        value: folder,
                        label: {
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
                            .contentShape(Rectangle())
                        }
                    )
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.selectLabel(label.name)
                        }
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
                    .help("Add New Tag")
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            bottomStatusBar
        }
    }

    private var bottomStatusBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                // Connection status
                Button {
                    store.showAccountSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(store.status?.authenticated == true ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(store.status?.authenticated == true ? (store.status?.email ?? "Google Keep") : "Local Mode")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(store.status?.authenticated == true ? "Synced with Keep" : "Sign In to Sync")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Manage Google Keep Account")

                Spacer()

                // Manual sync button
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
                .help("Sync Now with Google Keep")

                // Account Settings button
                Button {
                    store.showAccountSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Account Settings")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial)
        }
    }

    private func countForFolder(_ folder: Folder) -> Int? {
        guard let s = store.status else { return nil }
        switch folder {
        case .all: return s.totalNotes
        case .pinned: return s.pinnedNotes
        case .trash: return s.trashNotes
        default: return nil
        }
    }

    private func countForLabel(_ labelName: String) -> Int {
        store.notes.filter { $0.labels.contains(labelName) }.count
    }
}
