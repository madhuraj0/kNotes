import SwiftUI

public struct SidebarView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredItem: SidebarItem? = nil

    public init(store: NotesStore) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Quick Access Section
                VStack(alignment: .leading, spacing: 3) {
                    Text("QUICK ACCESS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 2)

                    ForEach(Folder.allCases) { folder in
                        folderRow(for: folder)
                    }
                }

                // Tags Section
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("TAGS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.8))
                        Spacer()
                        Button {
                            store.showNewLabelSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(3)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
                        .focusable(false)
                        .help("Add New Tag (⌘T)")
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 2)

                    if store.labels.isEmpty {
                        Text("No tags yet")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(store.labels) { label in
                            tagRow(for: label)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 180, idealWidth: 210)
    }

    // MARK: - Folder Row
    private func folderRow(for folder: Folder) -> some View {
        let isSelected: Bool = {
            if case .folder(let f) = store.sidebarSelection {
                return f == folder
            }
            return false
        }()
        let item = SidebarItem.folder(folder)
        let isHovered = hoveredItem == item

        return HStack(spacing: 9) {
            Image(systemName: folder.iconName)
                .foregroundColor(folder.iconColor)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 18)
                .shadow(color: folder.iconColor.opacity(isSelected ? 0.5 : 0.0), radius: 3)

            Text(folder.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(.primary)

            Spacer()

            if let count = countForFolder(folder), count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .primary.opacity(0.9) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.16))
                }
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSelected
                        ? LinearGradient(colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : (isHovered ? LinearGradient(colors: [Color.primary.opacity(0.08), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .top, endPoint: .bottom)),
                    lineWidth: 0.8
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                hoveredItem = hovering ? item : nil
            }
        }
        .onTapGesture {
            store.sidebarSelection = item
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(folder.title), \(countForFolder(folder) ?? 0) notes")
    }

    // MARK: - Tag Row
    private func tagRow(for label: LabelItem) -> some View {
        let isSelected: Bool = {
            if case .tag(let t) = store.sidebarSelection {
                return t == label.name
            }
            return false
        }()
        let item = SidebarItem.tag(label.name)
        let isHovered = hoveredItem == item

        return HStack(spacing: 8) {
            Image(systemName: "number")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.accentColor)
                .frame(width: 18)

            Text(label.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(.primary)

            Spacer()

            let count = countForLabel(label.name)
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .primary.opacity(0.9) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background {
            if isSelected {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.16))
                }
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSelected
                        ? LinearGradient(colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : (isHovered ? LinearGradient(colors: [Color.primary.opacity(0.08), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .top, endPoint: .bottom)),
                    lineWidth: 0.8
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                hoveredItem = hovering ? item : nil
            }
        }
        .onTapGesture {
            store.sidebarSelection = item
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tag \(label.name), \(countForLabel(label.name)) notes")
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
