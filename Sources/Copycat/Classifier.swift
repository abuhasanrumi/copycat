import AppKit

/// Heuristics that decide whether copied text is a link, color, code (and which language), or plain text.
enum Classifier {
    static func classify(_ s: String) -> (kind: ClipKind, language: String?) {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)

        if !t.contains(where: \.isWhitespace),
           let url = URL(string: t), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil {
            return (.link, nil)
        }
        if ColorParser.parse(t) != nil { return (.color, nil) }
        if let lang = codeLanguage(t) { return (.code, lang) }
        return (.text, nil)
    }

    // MARK: Code detection

    private static let shellCommands = ["git ", "npm ", "npx ", "yarn ", "pnpm ", "brew ", "sudo ", "cd ", "ls ", "curl ",
                                        "docker ", "kubectl ", "pip ", "pip3 ", "swift ", "cargo ", "make ", "ssh ",
                                        "chmod ", "mkdir ", "rm ", "cat ", "grep ", "xcodebuild "]

    private static func codeLanguage(_ t: String) -> String? {
        guard t.count >= 3 else { return nil }

        if (t.hasPrefix("{") && t.hasSuffix("}")) || (t.hasPrefix("[") && t.hasSuffix("]") && t.count > 4),
           let data = t.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
            return "JSON"
        }

        let lines = t.components(separatedBy: "\n")
        if lines.count == 1 {
            if t.hasPrefix("$ ") || t.hasPrefix("#!/") || (t.count < 240 && shellCommands.contains { t.hasPrefix($0) }) {
                return "Shell"
            }
        }

        var score = 0
        let endings = lines.filter { l in
            let x = l.trimmingCharacters(in: .whitespaces)
            return x.hasSuffix(";") || x.hasSuffix("{") || x.hasSuffix("}") || x.hasSuffix("):") || x.hasSuffix(") {")
        }.count
        score += min(endings, 3)
        if t.contains("=>") || t.contains("->") || t.contains("::") || t.contains(":=") { score += 1 }
        if t.contains("()") || t.contains("){") || t.contains(") {") { score += 1 }
        if t.contains("</") || t.contains("/>") { score += 2 }
        if lines.filter({ $0.hasPrefix("  ") || $0.hasPrefix("\t") }).count >= 2 { score += 1 }
        let starts = ["func ", "def ", "class ", "import ", "const ", "let ", "var ", "function ", "return ", "if (", "for (",
                      "while (", "public ", "private ", "struct ", "enum ", "interface ", "package ", "#include", "fn ",
                      "use ", "SELECT ", "select ", "@", "from ", "export ", "async "]
        let hit = Set(lines.compactMap { l -> String? in
            let x = l.trimmingCharacters(in: .whitespaces)
            return starts.first { x.hasPrefix($0) }
        })
        score += min(hit.count, 3)
        if t.range(of: #"[a-zA-Z\-]+\s*:\s*[^;\n]+;"#, options: .regularExpression) != nil, t.contains("{") { score += 1 }

        let threshold = lines.count > 1 ? 3 : 3
        guard score >= threshold else { return nil }
        return guessLanguage(t)
    }

    private static func guessLanguage(_ t: String) -> String {
        let lower = t.lowercased()
        let candidates: [(String, [String])] = [
            ("Swift", ["func ", "guard ", "import swiftui", "import foundation", "@state", "let ", "var ", " -> ", "nil", "struct ", "some view"]),
            ("Python", ["def ", "import ", "elif ", "self.", "none", "print(", "):", "__init__", "lambda "]),
            ("JavaScript", ["const ", "=>", "function", "console.", "require(", "===", "export ", "undefined", "async "]),
            ("HTML", ["<div", "</", "<html", "<span", "<a ", "<p>", "<body"]),
            ("CSS", ["{\n", ": ", ";\n", "margin", "padding", "color:", "display:"]),
            ("SQL", ["select ", " from ", " where ", "insert into", "create table", "join "]),
            ("Go", ["package ", "func ", "fmt.", " := ", "go func"]),
            ("Rust", ["fn ", "let mut", "println!", "impl ", "pub fn", "::"]),
            ("Java", ["public class", "system.out", "public static", "private void", "new "]),
            ("C/C++", ["#include", "int main", "std::", "printf(", "nullptr"]),
            ("Shell", ["#!/bin", "sudo ", "echo ", "fi\n", "then\n", "$("]),
        ]
        var best = ("Code", 0)
        for (name, signals) in candidates {
            let n = signals.filter { lower.contains($0) }.count
            if n > best.1 { best = (name, n) }
        }
        return best.1 >= 2 ? best.0 : "Code"
    }

    // MARK: Secrets

    private static let secretPatterns: [NSRegularExpression] = [
        #"sk-[A-Za-z0-9_\-]{20,}"#,
        #"gh[pousr]_[A-Za-z0-9]{30,}"#,
        #"github_pat_[A-Za-z0-9_]{30,}"#,
        #"AKIA[0-9A-Z]{16}"#,
        #"AIza[0-9A-Za-z_\-]{35}"#,
        #"xox[baprs]-[A-Za-z0-9\-]{10,}"#,
        #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#,
        #"eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]*"#,
        #"Bearer\s+[A-Za-z0-9._\-]{20,}"#,
        #"(?i)(password|passwd|secret|token|api[_-]?key)\s*[=:]\s*\S{8,}"#,
    ].compactMap { try? NSRegularExpression(pattern: $0) }

    static func isSensitive(_ s: String) -> Bool {
        let range = NSRange(s.startIndex..., in: s)
        return secretPatterns.contains { $0.firstMatch(in: s, range: range) != nil }
    }
}

enum ColorParser {
    static func parse(_ s: String) -> NSColor? {
        let t = s.trimmingCharacters(in: .whitespaces).lowercased()
        guard t.count <= 40 else { return nil }

        if t.hasPrefix("#") {
            var hex = String(t.dropFirst())
            if hex.count == 3 || hex.count == 4 { hex = hex.map { "\($0)\($0)" }.joined() }
            guard hex.count == 6 || hex.count == 8, let v = UInt64(hex, radix: 16) else { return nil }
            let hasAlpha = hex.count == 8
            let r = CGFloat((v >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
            let g = CGFloat((v >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
            let b = CGFloat((v >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
            let a = hasAlpha ? CGFloat(v & 0xFF) / 255 : 1
            return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
        }

        let isRGB = t.hasPrefix("rgb"), isHSL = t.hasPrefix("hsl")
        guard (isRGB || isHSL), t.hasSuffix(")"), let open = t.firstIndex(of: "(") else { return nil }
        let nums = t[t.index(after: open)..<t.index(before: t.endIndex)]
            .split(whereSeparator: { ",/ ".contains($0) })
            .compactMap { Double($0.replacingOccurrences(of: "%", with: "")) }
        guard nums.count == 3 || nums.count == 4 else { return nil }
        let alpha = nums.count == 4 ? CGFloat(nums[3]) : 1
        if isRGB {
            return NSColor(srgbRed: nums[0] / 255, green: nums[1] / 255, blue: nums[2] / 255, alpha: alpha)
        }
        return NSColor(calibratedHue: nums[0] / 360, saturation: nums[1] / 100, brightness: 0, alpha: alpha)
            .hslToRGB(h: nums[0], s: nums[1] / 100, l: nums[2] / 100, a: alpha)
    }

    static func hex(_ c: NSColor) -> String {
        let c = c.usingColorSpace(.sRGB) ?? c
        return String(format: "#%02X%02X%02X", Int(round(c.redComponent * 255)), Int(round(c.greenComponent * 255)), Int(round(c.blueComponent * 255)))
    }

    static func rgb(_ c: NSColor) -> String {
        let c = c.usingColorSpace(.sRGB) ?? c
        return "rgb(\(Int(round(c.redComponent * 255))), \(Int(round(c.greenComponent * 255))), \(Int(round(c.blueComponent * 255))))"
    }

    static func isLight(_ c: NSColor) -> Bool {
        let c = c.usingColorSpace(.sRGB) ?? c
        return 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent > 0.6
    }
}

private extension NSColor {
    func hslToRGB(h: Double, s: Double, l: Double, a: CGFloat) -> NSColor {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = (h.truncatingRemainder(dividingBy: 360) / 60)
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let (r1, g1, b1): (Double, Double, Double)
        switch hp {
        case ..<1: (r1, g1, b1) = (c, x, 0)
        case ..<2: (r1, g1, b1) = (x, c, 0)
        case ..<3: (r1, g1, b1) = (0, c, x)
        case ..<4: (r1, g1, b1) = (0, x, c)
        case ..<5: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        let m = l - c / 2
        return NSColor(srgbRed: r1 + m, green: g1 + m, blue: b1 + m, alpha: a)
    }
}
