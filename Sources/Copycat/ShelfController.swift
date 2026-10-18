import AppKit
import SwiftUI
import Combine

final class ShelfPanel: NSPanel {
    var keyHandler: ((NSEvent) -> Bool)?
    var onResignKey: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyHandler?(event) == true { return }
        super.sendEvent(event)
    }

    // ⌘-shortcuts arrive as key equivalents; give the shelf's handler first refusal.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown, keyHandler?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

final class ShelfController {
    let model: ShelfModel
    private let panel: ShelfPanel
    private let height: CGFloat = 320
    private(set) var isVisible = false
    private let preview: PreviewController
    private var bag = Set<AnyCancellable>()
    private var outsideClickMonitor: Any?

    init(model: ShelfModel) {
        self.model = model
        preview = PreviewController(store: model.store)
        panel = ShelfPanel(contentRect: .zero,
                           styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: true)
        // Above the Dock and menu bar, like Paste.
        panel.isFloatingPanel = true  // must precede `level`: it resets the level to .floating
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.keyHandler = { [weak self] in self?.handleKey($0) ?? false }
        panel.onResignKey = { [weak self] in self?.hide() }
        // Keep an open preview in sync with the selection.
        model.$selected.sink { [weak self] _ in
            DispatchQueue.main.async { self?.refreshPreview() }
        }.store(in: &bag)
    }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        guard !isVisible else { return }
        isVisible = true
        model.reset()
        panel.contentView = NSHostingView(rootView: ShelfView(model: model))

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let f = screen.frame
        let target = NSRect(x: f.minX, y: f.minY, width: f.width, height: height)
        panel.setFrame(target.offsetBy(dx: 0, dy: -height), display: true)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        // Clicks in other apps don't always take key status from a non-activating panel.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }
    }

    func hide(completion: (() -> Void)? = nil) {
        guard isVisible else { completion?(); return }
        isVisible = false
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m); outsideClickMonitor = nil }
        preview.hide()
        let down = panel.frame.offsetBy(dx: 0, dy: -height)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(down, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !self.isVisible else { return }
            self.panel.orderOut(nil)
            self.panel.contentView = nil
            completion?()
        })
    }

    private func refreshPreview(force: Bool = false) {
        guard isVisible, force || preview.isVisible else { return }
        guard let item = model.visible.first(where: { $0.id == model.selected }) else { preview.hide(); return }
        preview.show(item, above: height)
    }

    private static let digitKeys: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]

    private func handleKey(_ e: NSEvent) -> Bool {
        let cmd = e.modifierFlags.contains(.command)
        if model.renaming != nil { return false }  // let the pinboard name field handle keys
        switch e.keyCode {
        case 123: model.move(-1); return true            // ←
        case 124: model.move(1); return true             // →
        case 36, 76: model.activateSelected(); return true // return / enter
        case 49 where model.query.isEmpty && !model.searching:  // space → preview
            if preview.isVisible { preview.hide() } else { refreshPreview(force: true) }
            return true
        case 53 where preview.isVisible:                 // esc closes preview first
            preview.hide(); return true
        case 53:                                         // esc
            if !model.query.isEmpty || model.searching { model.query = ""; model.searching = false } else { hide() }
            return true
        case 51 where model.query.isEmpty || cmd:        // delete
            model.deleteSelected(); return true
        case 35 where cmd:                               // ⌘P
            model.togglePinSelected(); return true
        case let k where cmd && Self.digitKeys.contains(k):  // ⌘1…⌘9
            model.paste(at: Self.digitKeys.firstIndex(of: k)!); return true
        case 48:                                         // tab
            model.cycleTab(e.modifierFlags.contains(.shift) ? -1 : 1); return true
        case 0 where cmd, 7 where cmd, 8 where cmd, 9 where cmd, 6 where cmd:
            // An accessory app has no Edit menu, so route standard editing shortcuts to the search field ourselves.
            let action: Selector
            switch e.keyCode {
            case 0: action = #selector(NSText.selectAll(_:))
            case 7: action = #selector(NSText.cut(_:))
            case 8: action = #selector(NSText.copy(_:))
            case 9: action = #selector(NSText.paste(_:))
            default: action = e.modifierFlags.contains(.shift) ? Selector(("redo:")) : Selector(("undo:"))
            }
            return NSApp.sendAction(action, to: nil, from: nil)
        default: return false
        }
    }
}
