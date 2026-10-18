import AppKit
import Carbon
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ClipStore()
    private lazy var monitor = ClipboardMonitor(store: store)
    private lazy var model = ShelfModel(store: store)
    private lazy var shelf = ShelfController(model: model)
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem!
    private var pauseItem: NSMenuItem!
    private var linkItem: NSMenuItem!
    private var loginItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start()
        installEditMenu()
        if CommandLine.arguments.contains("--show-shelf") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.shelf.show() }
        }
        model.onPaste = { [weak self] in self?.paste($0, transform: $1) }
        model.onIgnoreApp = { [weak self] item in
            guard let id = item.bundleID else { return }
            Preferences.ignore(id)
            self?.model.objectWillChange.send()
        }
        // ⇧⌘V, same default as Paste.
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            self?.shelf.toggle()
        }
        setupStatusItem()
        if !UserDefaults.standard.bool(forKey: "didShowWelcome") {
            DispatchQueue.main.async { self.showWelcome() }
        } else if !AXIsProcessTrusted() {
            requestAccessibility()
        }
    }

    /// Accessory apps show no menu bar, but an Edit menu still enables ⌘A/⌘C/⌘V/⌘X/⌘Z in text fields.
    private func installEditMenu() {
        let main = NSMenu()
        let editItem = NSMenuItem()
        main.addItem(editItem)
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        NSApp.mainMenu = main
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Copycat")

        let menu = NSMenu()
        let show = NSMenuItem(title: "Show Clipboard History", action: #selector(showShelf), keyEquivalent: "v")
        show.keyEquivalentModifierMask = [.command, .shift]
        show.target = self
        menu.addItem(show)
        pauseItem = NSMenuItem(title: "Pause Capturing", action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)
        let clear = NSMenuItem(title: "Clear History…", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        linkItem = NSMenuItem(title: "Fetch Link Previews", action: #selector(toggleLinkPreviews), keyEquivalent: "")
        linkItem.target = self
        linkItem.state = Preferences.fetchLinkPreviews ? .on : .off
        menu.addItem(linkItem)
        loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)
        let ignored = NSMenuItem(title: "Ignored Apps", action: nil, keyEquivalent: "")
        ignored.submenu = NSMenu()
        ignored.submenu?.delegate = self
        menu.addItem(ignored)
        menu.addItem(.separator())
        let about = NSMenuItem(title: "About Copycat", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let guide = NSMenuItem(title: "Setup Guide…", action: #selector(showWelcome), keyEquivalent: "")
        guide.target = self
        menu.addItem(guide)
        menu.addItem(NSMenuItem(title: "Quit Copycat", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func showShelf() {
        // Let the menu finish closing before the panel takes key.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.shelf.show() }
    }

    @objc private func togglePause() {
        monitor.paused.toggle()
        pauseItem.title = monitor.paused ? "Resume Capturing" : "Pause Capturing"
    }

    @objc private func toggleLinkPreviews() {
        Preferences.fetchLinkPreviews.toggle()
        linkItem.state = Preferences.fetchLinkPreviews ? .on : .off
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            NSLog("Launch at login failed: \(error)")
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string: "A lightweight clipboard manager.\nPress ⇧⌘V to open your history."),
        ])
    }

    @objc private func showWelcome() {
        UserDefaults.standard.set(true, forKey: "didShowWelcome")
        let alert = NSAlert()
        alert.messageText = "Welcome to Copycat"
        alert.informativeText = """
        Copycat lives in your menu bar and remembers everything you copy.

        • Press ⇧⌘V anywhere to open your clipboard history.
        • Press Return (or double-click) to paste, Space to preview, ⌘P to pin.
        • To paste straight into other apps, allow Copycat under System Settings → Privacy & Security → Accessibility. Without it, the item is copied and you press ⌘V yourself.
        """
        let check = NSButton(checkboxWithTitle: "Open Copycat at login", target: nil, action: nil)
        check.state = true ? NSControl.StateValue.on : .off
        check.frame = NSRect(x: 0, y: 0, width: 260, height: 22)
        alert.accessoryView = check
        alert.addButton(withTitle: "Got It")
        alert.addButton(withTitle: "Open Accessibility Settings")
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if check.state == .on, SMAppService.mainApp.status != .enabled { try? SMAppService.mainApp.register() }
        if check.state == .off, SMAppService.mainApp.status == .enabled { try? SMAppService.mainApp.unregister() }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        if response == .alertSecondButtonReturn {
            requestAccessibility()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear all clipboard history?"
        alert.informativeText = "This can't be undone."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { store.clear() }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let header = NSMenuItem(title: "Click an app to resume capturing it", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for id in Preferences.ignoredBundleIDs {
            let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
                .map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") } ?? id
            let item = NSMenuItem(title: name, action: #selector(unignore(_:)), keyEquivalent: "")
            item.representedObject = id
            item.target = self
            menu.addItem(item)
        }
    }

    @objc private func unignore(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { Preferences.unignore(id) }
    }

    private func requestAccessibility() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: - Pasting

    private func paste(_ item: ClipItem, transform: Transform?) {
        write(item, transform: transform)
        monitor.syncChangeCount()
        if transform == nil { store.bump(item.id) }
        shelf.hide()

        guard AXIsProcessTrusted() else {
            requestAccessibility()  // item is on the clipboard; user can ⌘V manually
            return
        }
        // Wait for the panel to give key status back to the previous app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { Self.sendCommandV() }
    }

    private func write(_ item: ClipItem, transform: Transform?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text, .link, .code, .color:
            let raw = item.text ?? ""
            pb.setString(transform?.apply(raw) ?? raw, forType: .string)
        case .image:
            if let url = store.imageURL(for: item), let img = NSImage(contentsOf: url) { pb.writeObjects([img]) }
        case .file:
            pb.writeObjects((item.filePaths ?? []).map { URL(fileURLWithPath: $0) as NSURL })
        }
    }

    private static func sendCommandV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
