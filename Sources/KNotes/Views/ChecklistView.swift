import SwiftUI
import UniformTypeIdentifiers

public struct ChecklistView: View {
    @Binding var items: [ChecklistItem]
    var onUpdate: () -> Void

    @State private var newItemText: String = ""
    @State private var showCompleted: Bool = true
    @State private var draggingItem: ChecklistItem? = nil
    @FocusState private var focusedItemId: String?

    public init(items: Binding<[ChecklistItem]>, onUpdate: @escaping () -> Void) {
        self._items = items
        self.onUpdate = onUpdate
    }

    private var activeItems: [ChecklistItem] {
        items.filter { !$0.checked }
    }

    private var completedItems: [ChecklistItem] {
        items.filter { $0.checked }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Active items with drag and drop reordering
            ForEach(activeItems) { item in
                checklistRow(for: item)
                    .onDrag {
                        self.draggingItem = item
                        return NSItemProvider(object: (item.id ?? UUID().uuidString) as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: ChecklistDropDelegate(
                            targetItem: item,
                            items: $items,
                            draggingItem: $draggingItem,
                            onUpdate: onUpdate
                        )
                    )
            }

            // New item row
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))

                TextField("Add an item...", text: $newItemText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit {
                        commitNewItem()
                    }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 2)

            // Completed items section
            if !completedItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .padding(.vertical, 6)

                    Button {
                        withAnimation {
                            showCompleted.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            Text("\(completedItems.count) Completed Items")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)

                    if showCompleted {
                        ForEach(completedItems) { item in
                            checklistRow(for: item)
                        }
                    }
                }
            }
        }
    }

    private func checklistRow(for item: ChecklistItem) -> some View {
        HStack(spacing: 8) {
            // Drag grip indicator
            Image(systemName: "circle.grid.2x3.fill")
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.35))
                .frame(width: 12)
                .help("Drag to reorder")

            // Checkbox
            Button {
                toggleCheck(for: item)
            } label: {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.checked ? .accentColor : .secondary.opacity(0.8))
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)

            // Item text field
            TextField(
                "",
                text: Binding(
                    get: { item.text },
                    set: { newText in
                        updateItemText(for: item, newText: newText)
                    }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .strikethrough(item.checked, color: .secondary)
            .foregroundColor(item.checked ? .secondary : .primary)
            .focused($focusedItemId, equals: item.id)
            .onKeyPress(.delete) {
                if item.text.isEmpty && items.count > 1 {
                    handleBackspaceOnEmptyItem(item)
                    return .handled
                }
                return .ignored
            }
            .onSubmit {
                if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    focusedItemId = nil
                } else {
                    insertItemAfter(item)
                }
            }

            Spacer()

            // Delete item button
            Button {
                deleteItem(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Delete item")
            .accessibilityLabel("Delete checklist item")
        }
        .padding(.vertical, 3)
        .background(draggingItem?.id == item.id ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(6)
    }

    private func handleBackspaceOnEmptyItem(_ item: ChecklistItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        if index > 0 {
            focusedItemId = items[index - 1].id
        } else if index + 1 < items.count {
            focusedItemId = items[index + 1].id
        } else {
            focusedItemId = nil
        }
        _ = withAnimation {
            items.remove(at: index)
        }
        onUpdate()
    }

    private func insertItemAfter(_ item: ChecklistItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let newItem = ChecklistItem(text: "", checked: false)
        withAnimation {
            items.insert(newItem, at: index + 1)
        }
        focusedItemId = newItem.id
        onUpdate()
    }

    private func toggleCheck(for item: ChecklistItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            items[index].checked.toggle()
        }
        onUpdate()
    }

    private func updateItemText(for item: ChecklistItem, newText: String) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].text = newText
        onUpdate()
    }

    private func deleteItem(_ item: ChecklistItem) {
        withAnimation {
            items.removeAll(where: { $0.id == item.id })
        }
        onUpdate()
    }

    private func commitNewItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let newItem = ChecklistItem(text: trimmed, checked: false)
            withAnimation {
                items.append(newItem)
            }
            newItemText = ""
            focusedItemId = newItem.id
            onUpdate()
        }
    }
}

// MARK: - Drag and Drop Reordering Delegate
struct ChecklistDropDelegate: DropDelegate {
    let targetItem: ChecklistItem
    @Binding var items: [ChecklistItem]
    @Binding var draggingItem: ChecklistItem?
    var onUpdate: () -> Void

    func dropEntered(info: DropInfo) {
        guard let source = draggingItem, source.id != targetItem.id,
              let fromIndex = items.firstIndex(where: { $0.id == source.id }),
              let toIndex = items.firstIndex(where: { $0.id == targetItem.id }) else { return }

        if fromIndex != toIndex {
            withAnimation(.easeInOut(duration: 0.2)) {
                items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        onUpdate()
        return true
    }
}
