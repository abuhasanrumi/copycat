import Foundation

/// Text transformations offered under "Paste As".
enum Transform: String, CaseIterable, Identifiable {
    case prettyJSON, minifyJSON
    case upper, lower, camel, snake, kebab, constant
    case base64Encode, base64Decode, urlEncode, urlDecode
    case trim, singleLine, sortLines, uniqueLines

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prettyJSON: return "Pretty-printed JSON"
        case .minifyJSON: return "Minified JSON"
        case .upper: return "UPPERCASE"
        case .lower: return "lowercase"
        case .camel: return "camelCase"
        case .snake: return "snake_case"
        case .kebab: return "kebab-case"
        case .constant: return "CONSTANT_CASE"
        case .base64Encode: return "Base64 Encoded"
        case .base64Decode: return "Base64 Decoded"
        case .urlEncode: return "URL Encoded"
        case .urlDecode: return "URL Decoded"
        case .trim: return "Trimmed Whitespace"
        case .singleLine: return "Single Line"
        case .sortLines: return "Sorted Lines"
        case .uniqueLines: return "Unique Lines"
        }
    }

    /// Returns nil when the transform doesn't apply to the input.
    func apply(_ s: String) -> String? {
        switch self {
        case .prettyJSON: return json(s, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        case .minifyJSON: return json(s, options: [.sortedKeys, .withoutEscapingSlashes])
        case .upper: return s.uppercased()
        case .lower: return s.lowercased()
        case .camel:
            let w = words(s)
            return w.isEmpty ? nil : w.enumerated().map { $0 == 0 ? $1.lowercased() : $1.capitalized }.joined()
        case .snake: return join(s, "_", lower: true)
        case .kebab: return join(s, "-", lower: true)
        case .constant: return join(s, "_", lower: false)
        case .base64Encode: return Data(s.utf8).base64EncodedString()
        case .base64Decode:
            guard let d = Data(base64Encoded: s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
            return String(data: d, encoding: .utf8)
        case .urlEncode: return s.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(.init(charactersIn: "-._~")))
        case .urlDecode: return s.removingPercentEncoding
        case .trim:
            return s.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .singleLine:
            return s.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }.joined(separator: " ")
        case .sortLines: return s.components(separatedBy: "\n").sorted().joined(separator: "\n")
        case .uniqueLines:
            var seen = Set<String>()
            return s.components(separatedBy: "\n").filter { seen.insert($0).inserted }.joined(separator: "\n")
        }
    }

    private func json(_ s: String, options: JSONSerialization.WritingOptions) -> String? {
        guard let data = s.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              JSONSerialization.isValidJSONObject(obj),
              let out = try? JSONSerialization.data(withJSONObject: obj, options: options) else { return nil }
        return String(data: out, encoding: .utf8)
    }

    private func words(_ s: String) -> [String] {
        // Split on separators and on lower→Upper camel boundaries.
        let spaced = s.replacingOccurrences(of: #"([a-z0-9])([A-Z])"#, with: "$1 $2", options: .regularExpression)
        return spaced.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    private func join(_ s: String, _ sep: String, lower: Bool) -> String? {
        let w = words(s)
        guard !w.isEmpty else { return nil }
        return w.map { lower ? $0.lowercased() : $0.uppercased() }.joined(separator: sep)
    }
}
