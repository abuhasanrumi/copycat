import SwiftUI
import AppKit

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct ShelfView: View {
    @ObservedObject var model: ShelfModel
    @FocusState private var searchFocused: Bool
    @FocusState private var renameFocused: Bool
    @State private var dropTarget: ShelfTab?
    @State private var appeared = false

    private var searchExpanded: Bool { model.searching || !model.query.isEmpty }

    var body: some View {
        let items = model.visible
        VStack(spacing: 14) {
            topBar
            if items.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                CardView(item: item, store: model.store,
                                         selected: item.id == model.selected,
                                         shortcut: index < 9 ? index + 1 : nil)
                                    .id(item.id)
                                    .onTapGesture(count: 2) { model.selected = item.id; model.onPaste(item, nil) }
                                    .onTapGesture { model.selected = item.id }
                                    .contextMenu { menu(for: item) }
                                    .onDrag {
                                        model.draggingID = item.id
                                        return provider(for: item)
                                    }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .offset(y: appeared ? 0 : 36)
                        .opacity(appeared ? 1 : 0)
                    }
                    .onChange(of: model.selected) { id in
                        guard let id else { return }
                        withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffect())
        .overlay(alignment: .top) { Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 1) }
        .onAppear {
            DispatchQueue.main.async { searchFocused = true }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82).delay(0.04)) { appeared = true }
        }
        .onChange(of: model.renaming) { id in
            if id != nil { DispatchQueue.main.async { renameFocused = true } }
            else { searchFocused = true }
        }
        .onChange(of: model.searching) { on in if on { searchFocused = true } }
    }

    // MARK: Context menu

    @ViewBuilder private func menu(for item: ClipItem) -> some View {
        Button("Paste") { model.onPaste(item, nil) }
        if item.isTextual, let text = item.text {
            Menu("Paste As") {
                ForEach(Transform.allCases) { t in
                    if let out = t.apply(text), out != text {
                        Button(t.title) { model.onPaste(item, t) }
                    }
                }
            }
        }
        Divider()
        Menu("Add to Pinboard") {
            ForEach(model.store.boards) { board in
                Button(board.name) { model.store.assign(item.id, to: board.id) }
            }
            if model.store.boards.isEmpty { Text("No pinboards yet") }
        }
        if item.board != nil {
            Button("Remove from Pinboard") { model.store.assign(item.id, to: nil) }
        }
        if item.bundleID != nil {
            Button("Ignore \(item.appName)") { model.onIgnoreApp(item) }
        }
        Button("Delete", role: .destructive) { model.store.remove(item.id) }
    }

    private func provider(for item: ClipItem) -> NSItemProvider {
        switch item.kind {
        case .link:
            if let u = URL(string: item.text ?? "") { return NSItemProvider(object: u as NSURL) }
        case .image:
            if let url = model.store.imageURL(for: item), let p = NSItemProvider(contentsOf: url) { return p }
        case .file:
            if let path = item.filePaths?.first, let p = NSItemProvider(contentsOf: URL(fileURLWithPath: path)) { return p }
        default: break
        }
        return NSItemProvider(object: (item.text ?? item.searchText) as NSString)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: model.store.items.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 30, weight: .light))
            Text(emptyText).font(.system(size: 14, weight: .medium))
            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    private var emptyText: String {
        if case .board = model.tab, model.query.isEmpty { return "Drop clips here with ⌘P or right-click → Add to Pinboard" }
        return model.store.items.isEmpty ? "Copy something to get started" : "Nothing found"
    }

    // MARK: Top bar

    private var topBar: some View {
        ZStack {
            HStack(spacing: 10) {
                searchControl
                tabButton(icon: "clock.arrow.circlepath", title: "Clipboard", color: nil, tab: .clipboard, id: nil)
                ForEach(model.store.boards) { board in
                    tabButton(icon: nil, title: board.name, color: board.color, tab: .board(board.id), id: board.id)
                }
                Button { model.addBoard() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("New Pinboard")
            }
            HStack {
                Spacer()
                moreMenu
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 34)
    }

    private var searchControl: some View {
        HStack(spacing: 6) {
            Button { withAnimation(.easeOut(duration: 0.15)) { model.searching.toggle() } } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TextField("Search", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($searchFocused)
                .frame(width: searchExpanded ? 170 : 1)
                .opacity(searchExpanded ? 1 : 0)

            if searchExpanded {
                Menu {
                    ForEach(ClipFilter.allCases) { f in
                        Button { model.filter = f } label: {
                            Label(f.rawValue, systemImage: model.filter == f ? "checkmark" : f.icon)
                        }
                    }
                } label: {
                    Image(systemName: model.filter == .all
                          ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Filter by type")
            }
        }
        .padding(.trailing, searchExpanded ? 8 : 0)
        .background(Capsule().fill(Color.primary.opacity(searchExpanded ? 0.08 : 0)))
        .animation(.easeOut(duration: 0.15), value: searchExpanded)
    }

    @ViewBuilder
    private func tabButton(icon: String?, title: String, color: Color?, tab: ShelfTab, id: UUID?) -> some View {
        let on = model.tab == tab
        Button { model.tab = tab } label: {
            HStack(spacing: 7) {
                if let icon { Image(systemName: icon).font(.system(size: 14)) }
                if let color { Circle().fill(color).frame(width: 12, height: 12) }
                if let id, model.renaming == id {
                    TextField("Name", text: Binding(
                        get: { model.store.boards.first { $0.id == id }?.name ?? "" },
                        set: { model.store.renameBoard(id, to: $0) }))
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .frame(width: 110)
                        .focused($renameFocused)
                        .onSubmit { model.renaming = nil }
                        .onExitCommand { model.renaming = nil }
                } else {
                    Text(title).font(.system(size: 14))
                }
            }
            .foregroundStyle(on ? Color.primary : Color.primary.opacity(0.7))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(on ? 0.1 : 0)))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(dropTarget == tab ? 1.08 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dropTarget)
        .onDrop(of: [.data, .text, .url, .fileURL, .image], isTargeted: Binding(
            get: { dropTarget == tab },
            set: { if $0 { dropTarget = tab } else if dropTarget == tab { dropTarget = nil } })
        ) { _ in
            guard let dragged = model.draggingID else { return false }
            model.draggingID = nil
            switch tab {
            case .clipboard: model.store.assign(dragged, to: nil)
            case .board(let b): model.store.assign(dragged, to: b)
            }
            return true
        }
        .contextMenu {
            if let id {
                Button("Rename") { model.tab = tab; model.renaming = id }
                Button("Delete Pinboard", role: .destructive) { model.tab = tab; model.deleteCurrentBoard() }
            }
        }
    }

    private var moreMenu: some View {
        Menu {
            if case .board = model.tab {
                Button("Rename Pinboard") { model.renameCurrentBoard() }
                Button("Delete Pinboard", role: .destructive) { model.deleteCurrentBoard() }
                Divider()
            }
            Text("⌘P pin · ⌘1–9 quick paste · ⇥ switch tab · ⌫ delete")
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct CardView: View {
    let item: ClipItem
    let store: ClipStore
    let selected: Bool
    let shortcut: Int?
    @State private var hovering = false

    private static let width: CGFloat = 230
    private static let height: CGFloat = 236
    private static let radius: CGFloat = 16

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private var swatch: NSColor? { item.kind == .color ? ColorParser.parse(item.text ?? "") : nil }
    private var hidden: Bool { item.isSensitive && !hovering }
    private var boardColor: Color? { store.boards.first { $0.id == item.board }?.color }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                body(for: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()
                    .blur(radius: hidden ? 7 : 0)
                if hidden {
                    Label("Sensitive", systemImage: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.6))
                }
            }
            footer
        }
        .frame(width: Self.width, height: Self.height)
        .background(Color(white: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: Self.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: selected ? 4 : 0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(selected || hovering ? 0.2 : 0.1), radius: selected || hovering ? 12 : 5, y: selected || hovering ? 6 : 2)
        .offset(y: hovering && !selected ? -3 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: hovering)
        .onHover { hovering = $0 }
    }

    private var header: some View {
        ZStack(alignment: .trailing) {
            Color(nsColor: AppIcons.color(for: item.bundleID))
            Image(nsImage: AppIcons.icon(for: item.bundleID))
                .resizable()
                .scaledToFit()
                .frame(width: 68, height: 68)
                .offset(x: 12, y: 8)
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).font(.system(size: 15, weight: .semibold))
                    Text(Self.relative.localizedString(for: item.date, relativeTo: Date()))
                        .font(.system(size: 11)).opacity(0.8)
                }
                .foregroundStyle(.white)
                Spacer()
            }
            .padding(.leading, 12)
        }
        .frame(height: 56)
        .clipped()
    }

    private var footer: some View {
        ZStack {
            Text(item.footer)
                .font(.system(size: 11))
                .foregroundStyle(Color.black.opacity(0.5))
                .lineLimit(1)
                .padding(.horizontal, 36)
            HStack {
                if let c = boardColor { Circle().fill(c).frame(width: 8, height: 8) }
                Spacer()
                if let n = shortcut {
                    Text("⌘\(n)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.35))
                }
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 26)
    }

    @ViewBuilder private var linkBody: some View {
        let host = URL(string: item.text ?? "")?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
        let thumb = store.imageURL(for: item).flatMap { AppIcons.thumbnail(for: $0) }
        let isPhoto = (item.imageWidth ?? 0) >= 200
        VStack(alignment: .leading, spacing: 0) {
            if let thumb, isPhoto {
                Color.clear.frame(height: 82).overlay(Image(nsImage: thumb).resizable().scaledToFill()).clipped()
            }
            VStack(alignment: .leading, spacing: 4) {
                if let thumb, !isPhoto {
                    Image(nsImage: thumb).resizable().scaledToFit().frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                } else if thumb == nil {
                    Image(systemName: "link.circle.fill").font(.system(size: 26)).foregroundStyle(Color.accentColor)
                }
                Text(item.linkTitle ?? host)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(isPhoto ? 2 : 3)
                Text(host)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .lineLimit(1)
            }
            .padding(10)
        }
    }

    @ViewBuilder private func body(for item: ClipItem) -> some View {
        switch item.kind {
        case .text:
            let t = item.text ?? ""
            let short = t.count <= 40 && !t.contains("\n")
            Text(String(t.prefix(500)))
                .font(.system(size: short ? 20 : 12.5, weight: short ? .semibold : .regular))
                .foregroundStyle(Color.black.opacity(0.85))
                .padding(short ? 14 : 10)
        case .code:
            Text(Highlighter.attributed(for: item))
                .font(.system(size: 11, design: .monospaced))
                .lineSpacing(2)
                .padding(10)
        case .color:
            if let c = swatch {
                let light = ColorParser.isLight(c)
                ZStack(alignment: .bottomLeading) {
                    Color(nsColor: c)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ColorParser.hex(c)).font(.system(size: 20, weight: .bold, design: .monospaced))
                        Text(ColorParser.rgb(c)).font(.system(size: 11, design: .monospaced)).opacity(0.7)
                    }
                    .foregroundStyle(light ? Color.black.opacity(0.85) : .white)
                    .padding(12)
                }
            }
        case .link:
            linkBody
        case .image:
            if let url = store.imageURL(for: item), let img = AppIcons.thumbnail(for: url) {
                Color.clear.overlay(Image(nsImage: img).resizable().scaledToFill())
            }
        case .file:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array((item.filePaths ?? []).prefix(4)), id: \.self) { path in
                    HStack(spacing: 6) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                            .resizable().frame(width: 22, height: 22)
                        Text((path as NSString).lastPathComponent)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.black.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                if (item.filePaths?.count ?? 0) > 4 {
                    Text("+ \((item.filePaths?.count ?? 0) - 4) more")
                        .font(.system(size: 11)).foregroundStyle(Color.black.opacity(0.5))
                }
            }
            .padding(10)
        }
    }
}
