import SwiftUI

/// Lightweight, language-agnostic syntax highlighter for card previews.
enum Highlighter {
    private static let cache = NSCache<NSString, NSAttributedStringBox>()

    private final class NSAttributedStringBox {
        let value: AttributedString
        init(_ v: AttributedString) { value = v }
    }

    private static let keywords: Set<String> = [
        "func", "let", "var", "const", "def", "class", "struct", "enum", "protocol", "extension", "interface", "type",
        "import", "from", "export", "default", "return", "if", "else", "elif", "for", "while", "switch", "case", "break",
        "continue", "guard", "in", "is", "as", "try", "catch", "throw", "throws", "async", "await", "public", "private",
        "protected", "static", "final", "new", "package", "fn", "pub", "impl", "use", "mut", "self", "this", "super",
        "nil", "null", "none", "None", "true", "false", "True", "False", "undefined", "function", "yield", "lambda",
        "select", "SELECT", "FROM", "WHERE", "INSERT", "INTO", "JOIN", "AND", "OR", "NOT", "NULL", "echo", "do", "then",
        "fi", "done", "override", "init", "where", "some", "any", "with", "pass", "raise", "except", "finally", "defer",
    ]

    // GitHub-light palette; cards are white.
    private static let theme = (
        base: Color(red: 0.14, green: 0.16, blue: 0.18),
        keyword: Color(red: 0.81, green: 0.13, blue: 0.18),
        string: Color(red: 0.04, green: 0.19, blue: 0.41),
        number: Color(red: 0.02, green: 0.31, blue: 0.68),
        comment: Color(red: 0.43, green: 0.47, blue: 0.51),
        type: Color(red: 0.51, green: 0.32, blue: 0.87),
        call: Color(red: 0.07, green: 0.39, blue: 0.16)
    )

    private static let rules: [(NSRegularExpression, Color)] = {
        func re(_ p: String, _ o: NSRegularExpression.Options = []) -> NSRegularExpression { try! NSRegularExpression(pattern: p, options: o) }
        // Order matters: later rules paint over earlier ones.
        return [
            (re(#"\b[A-Z][A-Za-z0-9_]*\b"#), theme.type),
            (re(#"\b[a-z_][A-Za-z0-9_]*(?=\()"#), theme.call),
            (re(#"\b(0x[0-9a-fA-F]+|\d+(\.\d+)?)\b"#), theme.number),
            (re(#"\b[A-Za-z_][A-Za-z0-9_]*\b"#), theme.keyword),   // filtered to keywords below
            (re(#""(\\.|[^"\\\n])*"|'(\\.|[^'\\\n])*'|`[^`]*`"#), theme.string),
            (re(#"(//|--|(?<![\w&])#(?![0-9A-Fa-f]{3,8}\b)).*$"#, .anchorsMatchLines), theme.comment),
            (re(#"/\*[\s\S]*?\*/"#), theme.comment),
        ]
    }()

    static func attributed(for item: ClipItem, maxChars: Int = 900, maxLines: Int = 16) -> AttributedString {
        let key = "\(item.id.uuidString)-\(maxChars)" as NSString
        if let hit = cache.object(forKey: key) { return hit.value }

        let text = String((item.text ?? "").prefix(maxChars))
        let lines = text.components(separatedBy: "\n").prefix(maxLines).joined(separator: "\n")
        var out = AttributedString(lines)
        out.foregroundColor = theme.base

        let ns = lines as NSString
        let full = NSRange(location: 0, length: ns.length)
        for (regex, color) in rules {
            regex.enumerateMatches(in: lines, range: full) { m, _, _ in
                guard let m else { return }
                if color == theme.keyword, !keywords.contains(ns.substring(with: m.range)) { return }
                if let r = Range(m.range, in: out) { out[r].foregroundColor = color }
            }
        }
        cache.setObject(NSAttributedStringBox(out), forKey: key)
        return out
    }
}
