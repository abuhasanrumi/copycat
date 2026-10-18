import AppKit
import ImageIO

/// Caches source-app icons, their dominant header colors, and image thumbnails.
enum AppIcons {
    private static var icons: [String: NSImage] = [:]
    private static var colors: [String: NSColor] = [:]
    private static let thumbs = NSCache<NSURL, NSImage>()

    static func icon(for bundleID: String?) -> NSImage {
        guard let bundleID else { return NSImage(systemSymbolName: "questionmark.app", accessibilityDescription: nil)! }
        if let cached = icons[bundleID] { return cached }
        let img: NSImage
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            img = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            img = NSImage(systemSymbolName: "app", accessibilityDescription: nil)!
        }
        icons[bundleID] = img
        return img
    }

    static func color(for bundleID: String?) -> NSColor {
        let key = bundleID ?? ""
        if let cached = colors[key] { return cached }
        let c = dominantColor(icon(for: bundleID))
        colors[key] = c
        return c
    }

    static func thumbnail(for url: URL, maxPixel: Int = 640) -> NSImage? {
        if let cached = thumbs.object(forKey: url as NSURL) { return cached }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        thumbs.setObject(img, forKey: url as NSURL)
        return img
    }

    private static func dominantColor(_ img: NSImage) -> NSColor {
        let size = 24
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return .systemGray }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        img.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        NSGraphicsContext.restoreGraphicsState()

        var r = 0.0, g = 0.0, b = 0.0, total = 0.0
        for x in 0..<size {
            for y in 0..<size {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), c.alphaComponent > 0.5 else { continue }
                // Favor saturated pixels so white/gray highlights don't wash the color out.
                let w = 0.1 + Double(c.saturationComponent)
                r += Double(c.redComponent) * w
                g += Double(c.greenComponent) * w
                b += Double(c.blueComponent) * w
                total += w
            }
        }
        guard total > 0 else { return .systemGray }
        let base = NSColor(deviceRed: r / total, green: g / total, blue: b / total, alpha: 1)
        // Soften: pull saturation down a touch and keep brightness in a mid range so headers feel calm, not neon.
        let sat = min(base.saturationComponent * 0.8, 0.72)
        let bri = min(max(base.brightnessComponent, 0.22), 0.8)
        return NSColor(deviceHue: base.hueComponent, saturation: sat, brightness: bri, alpha: 1)
    }
}
