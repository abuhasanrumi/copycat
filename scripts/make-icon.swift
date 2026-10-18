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

    // Two overlapping cat heads: the back one is the "copy".
    let u = rect.width
    let origin = rect.origin
    func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: origin.x + x * u, y: origin.y + y * u) }

    func catHead(cx: CGFloat, cy: CGFloat) -> [NSBezierPath] {
        let w: CGFloat = 0.54, h: CGFloat = 0.42
        let head = NSBezierPath(roundedRect: NSRect(x: pt(cx - w / 2, cy - h / 2).x, y: pt(cx, cy - h / 2).y,
                                                    width: w * u, height: h * u), xRadius: 0.2 * w * u, yRadius: 0.24 * h * u)
        func ear(_ side: CGFloat) -> NSBezierPath {
            let p = NSBezierPath()
            p.move(to: pt(cx + side * 0.50 * w, cy + 0.05 * h))
            p.line(to: pt(cx + side * 0.40 * w, cy + 0.5 * h + 0.30 * h))
            p.line(to: pt(cx + side * 0.06 * w, cy + 0.5 * h - 0.02 * h))
            p.close()
            p.lineJoinStyle = .round
            p.lineWidth = 0.035 * u
            return p
        }
        return [head, ear(-1), ear(1)]
    }

    // Back copy (soft lavender, offset up and right).
    NSColor(srgbRed: 0.80, green: 0.82, blue: 1.0, alpha: 1).set()
    for p in catHead(cx: 0.55, cy: 0.52) { p.fill(); p.stroke() }

    // Front cat (white) with the face cut out in the gradient's mid tone.
    // Draw the whole head inside one transparency layer so the shadow falls on the silhouette, not on each piece.
    let cg = NSGraphicsContext.current!.cgContext
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -s * 0.015), blur: s * 0.03,
                 color: NSColor.black.withAlphaComponent(0.28).cgColor)
    cg.beginTransparencyLayer(auxiliaryInfo: nil)
    NSColor.white.set()
    let fcx: CGFloat = 0.46, fcy: CGFloat = 0.46
    for p in catHead(cx: fcx, cy: fcy) { p.fill(); p.stroke() }
    cg.endTransparencyLayer()
    cg.restoreGState()

    let ink = NSColor(srgbRed: 0.33, green: 0.33, blue: 0.86, alpha: 1)
    ink.set()
    for side in [-1.0, 1.0] as [CGFloat] {
        let e = NSBezierPath(ovalIn: NSRect(x: pt(fcx + side * 0.115 - 0.036, 0).x, y: pt(0, fcy + 0.0).y,
                                            width: 0.072 * u, height: 0.10 * u))
        e.fill()
    }
    let nose = NSBezierPath()
    nose.move(to: pt(fcx - 0.032, fcy - 0.03))
    nose.line(to: pt(fcx + 0.032, fcy - 0.03))
    nose.line(to: pt(fcx, fcy - 0.07))
    nose.close()
    nose.lineJoinStyle = .round
    nose.lineWidth = 0.012 * u
    nose.fill(); nose.stroke()
    let mouth = NSBezierPath()
    mouth.move(to: pt(fcx, fcy - 0.07))
    mouth.curve(to: pt(fcx - 0.06, fcy - 0.105), controlPoint1: pt(fcx, fcy - 0.10), controlPoint2: pt(fcx - 0.03, fcy - 0.115))
    mouth.move(to: pt(fcx, fcy - 0.07))
    mouth.curve(to: pt(fcx + 0.06, fcy - 0.105), controlPoint1: pt(fcx, fcy - 0.10), controlPoint2: pt(fcx + 0.03, fcy - 0.115))
    mouth.lineWidth = 0.014 * u
    mouth.lineCapStyle = .round
    mouth.stroke()
    let whiskers = NSBezierPath()
    for side in [-1.0, 1.0] as [CGFloat] {
        for (dy, tilt) in [(0.012, 0.022), (-0.022, 0.0), (-0.056, -0.022)] as [(CGFloat, CGFloat)] {
            whiskers.move(to: pt(fcx + side * 0.15, fcy - 0.05 + dy))
            whiskers.line(to: pt(fcx + side * 0.245, fcy - 0.05 + dy + tilt))
        }
    }
    whiskers.lineWidth = 0.011 * u
    whiskers.lineCapStyle = .round
    whiskers.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                              ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)]
for (name, px) in sizes {
    try! render(px).write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
