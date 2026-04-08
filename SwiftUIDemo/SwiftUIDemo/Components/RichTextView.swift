import SwiftUI

/// Renders a Contentful Rich Text document as SwiftUI views.
struct RichTextView: View {
    let document: [String: Any]?
    var textColor: Color?

    var body: some View {
        if let content = document?["content"] as? [[String: Any]] {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(content.enumerated()), id: \.offset) { _, node in
                    RichTextBlockNode(node: node, textColor: textColor)
                }
            }
        }
    }
}

// MARK: - Block Node View

/// Renders a single block-level rich text node.
/// Extracted as a separate view to avoid opaque return type inference issues.
private struct RichTextBlockNode: View {
    let node: [String: Any]
    let textColor: Color?

    private var nodeType: String {
        node["nodeType"] as? String ?? ""
    }

    var body: some View {
        Group {
            switch nodeType {
            case "paragraph":
                RichTextInline(node: node, textColor: textColor)
                    .font(.system(size: 16))
                    .foregroundColor(textColor ?? Color(hex: "#374151"))
                    .lineSpacing(4)
                    .padding(.bottom, 8)

            case "heading-1":
                RichTextInline(node: node, textColor: textColor)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(textColor ?? Color(hex: "#111827"))
                    .lineSpacing(4)
                    .padding(.bottom, 12)

            case "heading-2":
                RichTextInline(node: node, textColor: textColor)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textColor ?? Color(hex: "#111827"))
                    .lineSpacing(4)
                    .padding(.bottom, 10)

            case "heading-3":
                RichTextInline(node: node, textColor: textColor)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(textColor ?? Color(hex: "#111827"))
                    .lineSpacing(4)
                    .padding(.bottom, 8)

            case "heading-4", "heading-5", "heading-6":
                RichTextInline(node: node, textColor: textColor)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(textColor ?? Color(hex: "#1f2937"))
                    .lineSpacing(3)
                    .padding(.bottom, 6)

            case "unordered-list", "ordered-list":
                if let children = node["content"] as? [[String: Any]] {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                            RichTextBlockNode(node: child, textColor: textColor)
                        }
                    }
                }

            case "list-item":
                RichTextListItem(node: node, textColor: textColor)

            case "blockquote":
                RichTextBlockquote(node: node, textColor: textColor)

            case "hr":
                Divider()
                    .padding(.vertical, 12)

            default:
                if let content = node["content"] as? [[String: Any]] {
                    Text(RichTextHelpers.extractText(from: content))
                        .foregroundColor(textColor ?? Color(hex: "#374151"))
                }
            }
        }
    }
}

// MARK: - Inline Text View

/// Renders inline content (text with marks, links) as a single Text view.
private struct RichTextInline: View {
    let node: [String: Any]
    let textColor: Color?

    var body: some View {
        let text = buildText()
        text
    }

    private func buildText() -> Text {
        guard let children = node["content"] as? [[String: Any]] else { return Text("") }

        var result = Text("")
        for child in children {
            let childType = child["nodeType"] as? String ?? ""
            switch childType {
            case "text":
                result = result + RichTextHelpers.styledText(child)
            case "hyperlink":
                let linkText = RichTextHelpers.extractText(from: child["content"] as? [[String: Any]] ?? [])
                result = result + Text(linkText).foregroundColor(Color(hex: "#0070F3")).underline()
            case "embedded-entry-inline":
                result = result + Text("[…]")
            default:
                let text = RichTextHelpers.extractText(from: child["content"] as? [[String: Any]] ?? [])
                if !text.isEmpty {
                    result = result + Text(text)
                }
            }
        }
        return result
    }
}

// MARK: - List Item

private struct RichTextListItem: View {
    let node: [String: Any]
    let textColor: Color?

    var body: some View {
        let text = buildText()
        text
            .font(.system(size: 16))
            .foregroundColor(textColor ?? Color(hex: "#374151"))
            .padding(.bottom, 4)
    }

    private func buildText() -> Text {
        let children = node["content"] as? [[String: Any]] ?? []
        var result = Text("  \u{2022}  ")

        for child in children {
            let childType = child["nodeType"] as? String ?? ""
            if childType == "paragraph" {
                let grandchildren = child["content"] as? [[String: Any]] ?? []
                for gc in grandchildren {
                    let gcType = gc["nodeType"] as? String ?? ""
                    if gcType == "text" {
                        result = result + RichTextHelpers.styledText(gc)
                    } else {
                        let text = RichTextHelpers.extractText(from: gc["content"] as? [[String: Any]] ?? [])
                        if !text.isEmpty {
                            result = result + Text(text)
                        }
                    }
                }
            } else {
                let text = RichTextHelpers.extractText(from: child["content"] as? [[String: Any]] ?? [])
                if !text.isEmpty {
                    result = result + Text(text)
                }
            }
        }
        return result
    }
}

// MARK: - Blockquote

private struct RichTextBlockquote: View {
    let node: [String: Any]
    let textColor: Color?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(hex: "#0070F3"))
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 0) {
                if let children = node["content"] as? [[String: Any]] {
                    ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                        RichTextBlockNode(node: child, textColor: Color(hex: "#6b7280"))
                    }
                }
            }
            .padding(.leading, 12)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Helpers

enum RichTextHelpers {
    static func styledText(_ node: [String: Any]) -> Text {
        let value = node["value"] as? String ?? ""
        let marks = node["marks"] as? [[String: Any]] ?? []

        var text = Text(value)

        let isBold = marks.contains { ($0["type"] as? String) == "bold" }
        let isItalic = marks.contains { ($0["type"] as? String) == "italic" }
        let isUnderline = marks.contains { ($0["type"] as? String) == "underline" }

        if isBold { text = text.bold() }
        if isItalic { text = text.italic() }
        if isUnderline { text = text.underline() }

        return text
    }

    static func extractText(from nodes: [[String: Any]]) -> String {
        nodes.map { node -> String in
            if node["nodeType"] as? String == "text" {
                return node["value"] as? String ?? ""
            }
            if let children = node["content"] as? [[String: Any]] {
                return extractText(from: children)
            }
            return ""
        }.joined()
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
