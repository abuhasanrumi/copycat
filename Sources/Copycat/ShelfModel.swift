import Foundation
import Combine
import AppKit

enum ClipFilter: String, CaseIterable, Identifiable {
    case all = "All Types", text = "Text", code = "Code", links = "Links"
    case images = "Images", colors = "Colors", files = "Files"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "text.alignleft"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .links: return "link"
        case .images: return "photo"
        case .colors: return "paintpalette"
        case .files: return "doc"
        }
    }

    func matches(_ item: ClipItem) -> Bool {
        switch self {
        case .all: return true
        case .text: return item.kind == .text
        case .code: return item.kind == .code
        case .links: return item.kind == .link
        case .images: return item.kind == .image
        case .colors: return item.kind == .color
        case .files: return item.kind == .file
        }
    }
}

enum ShelfTab: Equatable {
    case clipboard
    case board(UUID)
}

final class ShelfModel: ObservableObject {
    @Published var query = ""
    @Published var searching = false
    @Published var filter: ClipFilter = .all
    @Published var tab: ShelfTab = .clipboard
    @Published var selected: UUID?
    @Published var renaming: UUID?
    var draggingID: UUID?

    let store: ClipStore
    var onPaste: (ClipItem, Transform?) -> Void = { _, _ in }
    var onIgnoreApp: (ClipItem) -> Void = { _ in }
    private var bag = Set<AnyCancellable>()

    init(store: ClipStore) {
        self.store = store
        store.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &bag)
        // Keep the selection on a visible card as the query/filter/tab changes.
        Publishers.CombineLatest3($query, $filter, $tab)
            .dropFirst()
            .sink { [weak self] _, _, _ in
                DispatchQueue.main.async { self?.selected = self?.visible.first?.id }
            }.store(in: &bag)
    }

    var visible: [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return store.items.filter { item in
            if case .board(let id) = tab, item.board != id { return false }
            return filter.matches(item) && (q.isEmpty
                || item.searchText.localizedCaseInsensitiveContains(q)
                || item.appName.localizedCaseInsensitiveContains(q)
                || (item.language?.localizedCaseInsensitiveContains(q) ?? false))
        }
    }

    func reset() {
        query = ""
        searching = false
        filter = .all
        tab = .clipboard
        renaming = nil
        selected = store.items.first?.id
    }

    func move(_ delta: Int) {
        let list = visible
        guard !list.isEmpty else { return }
        let current = list.firstIndex { $0.id == selected } ?? 0
        let next = list[max(0, min(list.count - 1, current + delta))].id
        if next != selected { NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default) }
        selected = next
    }

    // MARK: Tabs & pinboards

    func cycleTab(_ delta: Int) {
        let tabs: [ShelfTab] = [.clipboard] + store.boards.map { .board($0.id) }
        let i = tabs.firstIndex(of: tab) ?? 0
        tab = tabs[(i + delta + tabs.count) % tabs.count]
    }

    func addBoard() {
        let board = store.addBoard(named: "Pinboard \(store.boards.count + 1)")
        tab = .board(board.id)
        renaming = board.id
    }

    func deleteCurrentBoard() {
        guard case .board(let id) = tab else { return }
        tab = .clipboard
        store.deleteBoard(id)
    }

    func renameCurrentBoard() {
        if case .board(let id) = tab { renaming = id }
    }

    /// ⌘P: on a pinboard, unpins the card; on Clipboard, pins it to the first pinboard (creating one if needed).
    func togglePinSelected() {
        guard let id = selected else { return }
        switch tab {
        case .board:
            store.assign(id, to: nil)
            selected = visible.first(where: { $0.id != id })?.id
        case .clipboard:
            let board = store.boards.first ?? store.addBoard(named: "Pinboard 1")
            store.assign(id, to: board.id)
        }
    }

    // MARK: Actions

    func activateSelected() {
        if let item = visible.first(where: { $0.id == selected }) { onPaste(item, nil) }
    }

    /// ⌘1…⌘9 pastes the nth visible card.
    func paste(at index: Int) {
        let list = visible
        if index < list.count { onPaste(list[index], nil) }
    }

    func deleteSelected() {
        let list = visible
        guard let idx = list.firstIndex(where: { $0.id == selected }) else { return }
        let next = idx + 1 < list.count ? list[idx + 1].id : (idx > 0 ? list[idx - 1].id : nil)
        store.remove(list[idx].id)
        selected = next
    }
}
