import SwiftUI

public struct LiquidGlassSearchBar: View {
    @EnvironmentObject private var store: NotesStore
    @Binding var text: String
    var placeholder: String = "Search all notes..."
    @FocusState private var isSearchFocused: Bool

    public init(text: Binding<String>, placeholder: String = "Search all notes...") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isSearchFocused ? .primary : .secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isSearchFocused)
                .onExitCommand {
                    text = ""
                    isSearchFocused = false
                }
                .onChange(of: store.shouldFocusSearch) { _, shouldFocus in
                    if shouldFocus {
                        store.shouldFocusSearch = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isSearchFocused = true
                        }
                    }
                }

            if !text.isEmpty {
                Button {
                    text = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .focusable(false)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(width: 220)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSearchFocused ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: isSearchFocused ? 1.2 : 0.8)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
    }
}
