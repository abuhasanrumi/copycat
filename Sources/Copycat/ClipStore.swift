import AppKit
import Combine

final class ClipStore: ObservableObject {
    @Published private(set) var items: [ClipItem] = []
    @Published private(set) var boards: [Pinboard] = []

    static let maxItems = 500
    private let dir: URL
    private let imagesDir: URL
    private let indexURL: URL
    private let boardsURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("Copycat", isDirectory: true)
        // Carry history over from the app's earlier name.
        let legacy = base.appendingPathComponent("PasteClone", isDirectory: true)
        if FileManager.default.fileExists(atPath: legacy.path), !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.moveItem(at: legacy, to: dir)
        }
        imagesDir = dir.appendingPathComponent("images", isDirectory: true)
        indexURL = dir.appendingPathComponent("history.json")
        boardsURL = dir.appendingPathComponent("boards.json")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) {
            items = decoded
        }
        if let data = try? Data(contentsOf: boardsURL),
           let decoded = try? JSONDecoder().decode([Pinboard].self, from: data) {
            boards = decoded
        }
    }

    func imageURL(for item: ClipItem) -> URL? {
        item.imageFile.map { imagesDir.appendingPathComponent($0) }
    }

    func saveImage(_ png: Data) -> String? {
        let name = UUID().uuidString + ".png"
        do {
            try png.write(to: imagesDir.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    /// Adds an item; if identical content already exists it is moved to the top instead.
    func add(_ item: ClipItem) {
        if let idx = items.firstIndex(where: { $0.hash == item.hash }) {
            if let file = item.imageFile { try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(file)) }
            var existing = items.remove(at: idx)
            existing.date = item.date
            items.insert(existing, at: 0)
        } else {
            items.insert(item, at: 0)
        }
        prune()
        save()
    }

    func setOCR(hash: String, text: String) {
        guard let idx = items.firstIndex(where: { $0.hash == hash }) else { return }
        items[idx].ocr = text
        save()
    }

    /// Stores a fetched link title and preview image.
    func updateLink(hash: String, title: String?, png: Data?) {
        guard let idx = items.firstIndex(where: { $0.hash == hash }) else { return }
        items[idx].linkTitle = title
        if let png, let file = saveImage(png), let rep = NSBitmapImageRep(data: png) {
            if let old = items[idx].imageFile { try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(old)) }
            items[idx].imageFile = file
            items[idx].imageWidth = rep.pixelsWide
            items[idx].imageHeight = rep.pixelsHigh
        }
        save()
    }

    func bump(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items.remove(at: idx)
        item.date = Date()
        items.insert(item, at: 0)
        save()
    }

    func assign(_ id: UUID, to board: UUID?) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].board = board
        save()
    }

    @discardableResult
    func addBoard(named name: String) -> Pinboard {
        let board = Pinboard(name: name, colorIndex: boards.count % Pinboard.palette.count)
        boards.append(board)
        saveBoards()
        return board
    }

    func renameBoard(_ id: UUID, to name: String) {
        guard let idx = boards.firstIndex(where: { $0.id == id }) else { return }
        boards[idx].name = name
        saveBoards()
    }

    func deleteBoard(_ id: UUID) {
        boards.removeAll { $0.id == id }
        for i in items.indices where items[i].board == id { items[i].board = nil }
        saveBoards()
        save()
    }

    func remove(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        deleteFiles(items[idx])
        items.remove(at: idx)
        save()
    }

    func clear() {
        // Items on a pinboard survive a clear.
        items.filter { $0.board == nil }.forEach(deleteFiles)
        items.removeAll { $0.board == nil }
        save()
    }

    private func prune() {
        while items.count > Self.maxItems, let idx = items.lastIndex(where: { $0.board == nil }) {
            deleteFiles(items.remove(at: idx))
        }
    }

    private func deleteFiles(_ item: ClipItem) {
        if let url = imageURL(for: item) { try? FileManager.default.removeItem(at: url) }
    }

    private func saveBoards() {
        if let data = try? JSONEncoder().encode(boards) {
            try? data.write(to: boardsURL, options: .atomic)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }
}
