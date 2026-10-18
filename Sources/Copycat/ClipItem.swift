import Foundation

enum ClipKind: String, Codable {
    case text, link, image, file, code, color
}

struct ClipItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: ClipKind
    var text: String?
    var language: String?
    var imageFile: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var filePaths: [String]?
    var appName: String
    var bundleID: String?
    var date: Date
    var hash: String
    var board: UUID?
    var sensitive: Bool?
    var ocr: String?
    var linkTitle: String?

    var isSensitive: Bool { sensitive == true }

    var title: String {
        switch kind {
        case .text: return "Text"
        case .code: return "Code"
        case .color: return "Color"
        case .link: return "Link"
        case .image: return "Image"
        case .file: return (filePaths?.count ?? 0) > 1 ? "Files" : "File"
        }
    }

    var footer: String {
        switch kind {
        case .text:
            let n = text?.count ?? 0
            return "\(n) character\(n == 1 ? "" : "s")"
        case .code:
            let n = (text ?? "").split(separator: "\n", omittingEmptySubsequences: false).count
            return "\(language ?? "Code") · \(n) line\(n == 1 ? "" : "s")"
        case .color:
            return "Color"
        case .link:
            return URL(string: text ?? "")?.host ?? "Link"
        case .image:
            return "\(imageWidth ?? 0) × \(imageHeight ?? 0)"
        case .file:
            let n = filePaths?.count ?? 0
            return "\(n) file\(n == 1 ? "" : "s")"
        }
    }

    var searchText: String {
        switch kind {
        case .text, .code, .color: return text ?? ""
        case .link: return (text ?? "") + " " + (linkTitle ?? "")
        case .image: return "image " + (ocr ?? "")
        case .file: return (filePaths ?? []).map { ($0 as NSString).lastPathComponent }.joined(separator: " ")
        }
    }

    /// Items whose payload is plain text that can be transformed before pasting.
    var isTextual: Bool { [.text, .link, .code, .color].contains(kind) }
}
