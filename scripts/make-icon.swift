// Renders the app icon: swift scripts/make-icon.swift <output.iconset dir>
import AppKit

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: artwork occupies ~80% of the canvas.
    let inset = s * 0.1
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = s * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    path.addClip()
    NSGradient(colors: [NSColor(srgbRed: 0.36, green: 0.55, blue: 1.0, alpha: 1),
                        NSColor(srgbRed: 0.45, green: 0.25, blue: 0.95, alpha: 1)])!
        .draw(in: rect, angle: -60)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), .clear])!
        .draw(in: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: -90)

    // Glyph
    let config = NSImage.SymbolConfiguration(pointSize: s * 0.48, weight: .semibold)
    if let sym = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let tinted = NSImage(size: sym.size, flipped: false) { r in
            sym.draw(in: r)
            NSColor.white.set()
            r.fill(using: .sourceAtop)
            return true
        }
        let g = tinted.size
        let gs = NSShadow()
        gs.shadowColor = NSColor.black.withAlphaComponent(0.25)
        gs.shadowBlurRadius = s * 0.02
        gs.shadowOffset = NSSize(width: 0, height: -s * 0.01)
        gs.set()
        tinted.draw(in: NSRect(x: s / 2 - g.width / 2, y: s / 2 - g.height / 2, width: g.width, height: g.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                              ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)]
for (name, px) in sizes {
    try! render(px).write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
