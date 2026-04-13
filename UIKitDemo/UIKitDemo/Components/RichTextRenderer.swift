import UIKit

/// Converts Contentful Rich Text `[String: Any]` documents to `NSAttributedString`.
enum RichTextRenderer {

    static func render(_ document: [String: Any]?, textColor: UIColor? = nil) -> NSAttributedString {
        guard let content = document?["content"] as? [[String: Any]] else {
            return NSAttributedString()
        }

        let result = NSMutableAttributedString()
        for node in content {
            result.append(renderBlock(node, textColor: textColor))
        }

        // Trim trailing newline
        if result.length > 0, result.string.hasSuffix("\n") {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }

        return result
    }

    // MARK: - Block Rendering

    private static func renderBlock(_ node: [String: Any], textColor: UIColor?) -> NSAttributedString {
        let nodeType = node["nodeType"] as? String ?? ""

        switch nodeType {
        case "paragraph":
            return renderInline(node, font: .systemFont(ofSize: 16), color: textColor ?? UIColor(hex: "#374151"), spacingAfter: 8)

        case "heading-1":
            return renderInline(node, font: .systemFont(ofSize: 32, weight: .heavy), color: textColor ?? UIColor(hex: "#111827"), spacingAfter: 12)

        case "heading-2":
            return renderInline(node, font: .systemFont(ofSize: 24, weight: .bold), color: textColor ?? UIColor(hex: "#111827"), spacingAfter: 10)

        case "heading-3":
            return renderInline(node, font: .systemFont(ofSize: 20, weight: .semibold), color: textColor ?? UIColor(hex: "#111827"), spacingAfter: 8)

        case "heading-4", "heading-5", "heading-6":
            return renderInline(node, font: .systemFont(ofSize: 18, weight: .semibold), color: textColor ?? UIColor(hex: "#1f2937"), spacingAfter: 6)

        case "unordered-list", "ordered-list":
            let children = node["content"] as? [[String: Any]] ?? []
            let result = NSMutableAttributedString()
            for child in children {
                result.append(renderBlock(child, textColor: textColor))
            }
            return result

        case "list-item":
            return renderListItem(node, textColor: textColor)

        case "blockquote":
            return renderBlockquote(node, textColor: textColor)

        case "hr":
            return renderHorizontalRule()

        default:
            let children = node["content"] as? [[String: Any]] ?? []
            let text = extractText(from: children)
            if text.isEmpty { return NSAttributedString() }
            let attr = NSMutableAttributedString(string: text, attributes: [
                .foregroundColor: textColor ?? UIColor(hex: "#374151"),
                .font: UIFont.systemFont(ofSize: 16),
            ])
            attr.append(NSAttributedString(string: "\n"))
            return attr
        }
    }

    // MARK: - Inline Rendering

    private static func renderInline(
        _ node: [String: Any],
        font: UIFont,
        color: UIColor,
        spacingAfter: CGFloat
    ) -> NSAttributedString {
        guard let children = node["content"] as? [[String: Any]] else {
            return NSAttributedString()
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = spacingAfter
        paragraphStyle.lineSpacing = 4

        let result = NSMutableAttributedString()
        for child in children {
            let childType = child["nodeType"] as? String ?? ""
            switch childType {
            case "text":
                result.append(styledText(child, baseFont: font, baseColor: color))
            case "hyperlink":
                let linkText = extractText(from: child["content"] as? [[String: Any]] ?? [])
                let linkData = child["data"] as? [String: Any]
                let uri = linkData?["uri"] as? String ?? ""
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor(hex: "#0070F3"),
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .link: uri,
                ]
                result.append(NSAttributedString(string: linkText, attributes: attrs))
            default:
                let text = extractText(from: child["content"] as? [[String: Any]] ?? [])
                if !text.isEmpty {
                    result.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color]))
                }
            }
        }

        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    // MARK: - List Items

    private static func renderListItem(_ node: [String: Any], textColor: UIColor?) -> NSAttributedString {
        let children = node["content"] as? [[String: Any]] ?? []
        let font = UIFont.systemFont(ofSize: 16)
        let color = textColor ?? UIColor(hex: "#374151")

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 4
        paragraphStyle.headIndent = 24
        paragraphStyle.firstLineHeadIndent = 0

        let result = NSMutableAttributedString(string: "  \u{2022}  ", attributes: [
            .font: font,
            .foregroundColor: color,
        ])

        for child in children {
            let childType = child["nodeType"] as? String ?? ""
            if childType == "paragraph" {
                let grandchildren = child["content"] as? [[String: Any]] ?? []
                for gc in grandchildren {
                    let gcType = gc["nodeType"] as? String ?? ""
                    if gcType == "text" {
                        result.append(styledText(gc, baseFont: font, baseColor: color))
                    } else {
                        let text = extractText(from: gc["content"] as? [[String: Any]] ?? [])
                        if !text.isEmpty {
                            result.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color]))
                        }
                    }
                }
            } else {
                let text = extractText(from: child["content"] as? [[String: Any]] ?? [])
                if !text.isEmpty {
                    result.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color]))
                }
            }
        }

        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))
        result.append(NSAttributedString(string: "\n"))
        return result
    }

    // MARK: - Blockquote

    private static func renderBlockquote(_ node: [String: Any], textColor: UIColor?) -> NSAttributedString {
        let children = node["content"] as? [[String: Any]] ?? []
        let color = UIColor(hex: "#6b7280")

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 12
        paragraphStyle.headIndent = 12
        paragraphStyle.paragraphSpacingBefore = 8
        paragraphStyle.paragraphSpacing = 8

        let result = NSMutableAttributedString()
        for child in children {
            let inline = renderBlock(child, textColor: color)
            result.append(inline)
        }

        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))
        return result
    }

    // MARK: - Horizontal Rule

    private static func renderHorizontalRule() -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = 12
        paragraphStyle.paragraphSpacing = 12

        let line = String(repeating: "\u{2500}", count: 40)
        let result = NSMutableAttributedString(string: line + "\n", attributes: [
            .foregroundColor: UIColor(hex: "#d1d5db"),
            .font: UIFont.systemFont(ofSize: 12),
            .paragraphStyle: paragraphStyle,
        ])
        return result
    }

    // MARK: - Styled Text

    private static func styledText(_ node: [String: Any], baseFont: UIFont, baseColor: UIColor) -> NSAttributedString {
        let value = node["value"] as? String ?? ""
        let marks = node["marks"] as? [[String: Any]] ?? []

        let isBold = marks.contains { ($0["type"] as? String) == "bold" }
        let isItalic = marks.contains { ($0["type"] as? String) == "italic" }
        let isUnderline = marks.contains { ($0["type"] as? String) == "underline" }

        var font = baseFont
        if isBold || isItalic {
            var traits: UIFontDescriptor.SymbolicTraits = font.fontDescriptor.symbolicTraits
            if isBold { traits.insert(.traitBold) }
            if isItalic { traits.insert(.traitItalic) }
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                font = UIFont(descriptor: descriptor, size: font.pointSize)
            }
        }

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: baseColor,
        ]
        if isUnderline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        return NSAttributedString(string: value, attributes: attrs)
    }

    // MARK: - Text Extraction

    private static func extractText(from nodes: [[String: Any]]) -> String {
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

// MARK: - UIColor Hex Extension

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
