import SwiftUI

public struct MarkdownPreviewView: View {
    let markdownText: String
    let noteColor: Color

    public init(markdownText: String, noteColor: Color = .clear) {
        self.markdownText = markdownText
        self.noteColor = noteColor
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !markdownText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let blocks = parseMarkdownBlocks(markdownText)
                    ForEach(0..<blocks.count, id: \.self) { idx in
                        renderBlock(blocks[idx])
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func markdownStyledText(_ text: String) -> Text {
        if let attr = try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attr)
        }
        return Text(text)
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .header1(let text):
            markdownStyledText(text)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 8)
                .padding(.bottom, 2)

        case .header2(let text):
            markdownStyledText(text)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 6)
                .padding(.bottom, 2)

        case .header3(let text):
            markdownStyledText(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.top, 4)

        case .quote(let text):
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(width: 3)

                markdownStyledText(text)
                    .font(.system(size: 14).italic())
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Color.secondary.opacity(0.04))
            .cornerRadius(4)

        case .codeBlock(let code, let lang):
            VStack(alignment: .leading, spacing: 6) {
                if let lang = lang, !lang.isEmpty {
                    Text(lang.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.textBackgroundColor).opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .cornerRadius(8)

        case .bullet(let text):
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 5, height: 5)
                    .padding(.top, 7)

                markdownStyledText(text)
                    .font(.system(size: 14))
                    .lineSpacing(3)
            }

        case .numbered(let num, let text):
            HStack(alignment: .top, spacing: 6) {
                Text("\(num).")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 20, alignment: .leading)

                markdownStyledText(text)
                    .font(.system(size: 14))
                    .lineSpacing(3)
            }

        case .divider:
            Divider()
                .padding(.vertical, 6)

        case .paragraph(let text):
            markdownStyledText(text)
                .font(.system(size: 14))
                .lineSpacing(4)
                .textSelection(.enabled)
        }
    }

    private func parseMarkdownBlocks(_ raw: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = raw.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), lang: lang.isEmpty ? nil : lang))
                i += 1
                continue
            }

            // Headers
            if trimmed.hasPrefix("### ") {
                blocks.append(.header3(String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("## ") {
                blocks.append(.header2(String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("# ") {
                blocks.append(.header1(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("> ") {
                blocks.append(.quote(String(trimmed.dropFirst(2))))
            } else if trimmed == "---" || trimmed == "***" {
                blocks.append(.divider)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                blocks.append(.bullet(String(trimmed.dropFirst(2))))
            } else if let match = matchNumberedList(trimmed) {
                blocks.append(.numbered(match.0, match.1))
            } else if !trimmed.isEmpty {
                blocks.append(.paragraph(trimmed))
            }

            i += 1
        }

        return blocks
    }

    private func matchNumberedList(_ text: String) -> (Int, String)? {
        guard let dotIdx = text.firstIndex(of: ".") else { return nil }
        let numStr = text[..<dotIdx]
        guard let num = Int(numStr) else { return nil }
        let remainder = text[text.index(after: dotIdx)...].trimmingCharacters(in: .whitespaces)
        return (num, remainder)
    }
}

public enum MarkdownBlock {
    case header1(String)
    case header2(String)
    case header3(String)
    case quote(String)
    case codeBlock(code: String, lang: String?)
    case bullet(String)
    case numbered(Int, String)
    case divider
    case paragraph(String)
}
