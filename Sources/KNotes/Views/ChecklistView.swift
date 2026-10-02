import SwiftUI

public struct ChecklistView: View {
    @Binding var items: [ChecklistItem]
    var onUpdate: () -> Void

    @State private var newItemText: String = ""
    @State private var showCompleted: Bool = true
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
        VStack(alignment: .leading, spacing: 6) {
            // Active items
            ForEach(activeItems) { item in
                checklistRow(for: item)
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
            .padding(.vertical, 4)
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
            Button {
                toggleCheck(for: item)
            } label: {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.checked ? .accentColor : .secondary.opacity(0.8))
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)

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
            .onSubmit {
                commitNewItem()
            }

            Spacer()

            Button {
                deleteItem(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Delete item")
        }
        .padding(.vertical, 3)
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
            onUpdate()
        }
    }
}
