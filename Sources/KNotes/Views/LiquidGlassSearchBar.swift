import SwiftUI

public struct LiquidGlassSearchBar: View {
    @ObservedObject var store: NotesStore
    @Binding var text: String
    var placeholder: String = "Search all notes..."
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    public init(store: NotesStore, text: Binding<String>, placeholder: String = "Search all notes...") {
        self.store = store
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSearchFocused ? .primary : .secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($isSearchFocused)
                .onExitCommand {
                    if !text.isEmpty {
                        text = ""
                    } else {
                        isSearchFocused = false
                    }
                }
                .onSubmit {
                    if store.selectedNote != nil {
                        isSearchFocused = false
                        store.shouldFocusTitle = true
                    }
                }
                .onKeyPress(.downArrow) {
                    if !store.notes.isEmpty {
                        isSearchFocused = false
                        return .handled
                    }
                    return .ignored
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
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .focusable(false)
                .help("Clear Search")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSearchFocused
                        ? Color.accentColor.opacity(0.7)
                        : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08),
                    lineWidth: isSearchFocused ? 1.2 : 0.6
                )
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.10 : 0.02), radius: 2, x: 0, y: 1)
    }
}
