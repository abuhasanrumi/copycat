import SwiftUI
import AppKit

/// Quick Look–style large preview shown above the shelf (Space).
final class PreviewController {
    private let panel: NSPanel
    private let store: ClipStore
    private(set) var isVisible = false

    init(store: ClipStore) {
        self.store = store
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
    }

    func show(_ item: ClipItem, above shelfHeight: CGFloat) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let f = screen.frame
        let h = min(460, f.height - shelfHeight - 90)
        let w: CGFloat = 640
        let frame = NSRect(x: f.midX - w / 2, y: f.minY + shelfHeight + 14, width: w, height: h)
        panel.contentView = NSHostingView(rootView: PreviewView(item: item, store: store))
        if !isVisible {
            panel.setFrame(frame.offsetBy(dx: 0, dy: -12), display: true)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.16
                panel.animator().setFrame(frame, display: true)
                panel.animator().alphaValue = 1
            }
        } else {
            panel.setFrame(frame, display: true)
        }
        isVisible = true
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !self.isVisible else { return }
            self.panel.orderOut(nil)
            self.panel.contentView = nil
        })
    }
}

struct PreviewView: View {
    let item: ClipItem
    let store: ClipStore

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: AppIcons.icon(for: item.bundleID)).resizable().frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).font(.system(size: 14, weight: .semibold))
                    Text("\(item.appName) · \(Self.relative.localizedString(for: item.date, relativeTo: Date()))")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.footer).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(white: 0.985))
                .environment(\.colorScheme, .light)
        }
        .background(VisualEffect())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .text:
            ScrollView { Text(String((item.text ?? "").prefix(20000))).font(.system(size: 14)).foregroundStyle(.black.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading).padding(16) }
        case .code:
            ScrollView([.vertical, .horizontal]) {
                Text(Highlighter.attributed(for: item, maxChars: 20000, maxLines: 600))
                    .font(.system(size: 12.5, design: .monospaced))
                    .lineSpacing(3)
                    .padding(16)
            }
        case .color:
            if let c = ColorParser.parse(item.text ?? "") {
                ZStack(alignment: .bottomLeading) {
                    Color(nsColor: c)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ColorParser.hex(c)).font(.system(size: 34, weight: .bold, design: .monospaced))
                        Text(ColorParser.rgb(c)).font(.system(size: 15, design: .monospaced)).opacity(0.75)
                    }
                    .foregroundStyle(ColorParser.isLight(c) ? Color.black.opacity(0.85) : .white)
                    .padding(24)
                }
            }
        case .link:
            VStack(alignment: .leading, spacing: 10) {
                if let url = store.imageURL(for: item), let img = AppIcons.thumbnail(for: url, maxPixel: 1200) {
                    Image(nsImage: img).resizable().scaledToFit().frame(maxHeight: 220).cornerRadius(10)
                }
                if let t = item.linkTitle { Text(t).font(.system(size: 18, weight: .semibold)).foregroundStyle(.black) }
                Text(item.text ?? "").font(.system(size: 13)).foregroundStyle(Color.accentColor).textSelection(.enabled)
                Spacer()
            }.padding(16)
        case .image:
            if let url = store.imageURL(for: item), let img = AppIcons.thumbnail(for: url, maxPixel: 1600) {
                Image(nsImage: img).resizable().scaledToFit().padding(12)
            }
        case .file:
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(item.filePaths ?? [], id: \.self) { path in
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text((path as NSString).lastPathComponent).font(.system(size: 13, weight: .medium))
                                Text(path).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            }
                        }
                    }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
