// Renders Qutran's app icon and menu bar template icon into the asset catalog.
// Usage: swift scripts/personal/render_icons.swift <repo-root>
//
// Mark: a "Q" drawn as a speech bubble — a ring whose tail is the bubble's tail — holding 譯.
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Sources/OpenClip/Assets.xcassets")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func render(size: Int, draw: (CGContext, CGFloat) -> Void) -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    draw(ctx, CGFloat(size))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

/// The Q-bubble outline in a unit square (y up): ring centred slightly high, tail to the lower right.
func qBubblePath(in rect: CGRect, ringWidth: CGFloat) -> CGPath {
    let s = rect.width
    let center = CGPoint(x: rect.minX + s * 0.47, y: rect.minY + s * 0.53)
    let radius = s * 0.36
    let path = CGMutablePath()
    // Ring as an even-odd donut.
    path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    let inner = radius - ringWidth
    path.addEllipse(in: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2))
    // Tail: a tapered wedge leaving the ring at ~-45° and ending in a soft point.
    let angle = -CGFloat.pi / 4
    let base = CGPoint(x: center.x + cos(angle) * (radius - ringWidth * 0.5), y: center.y + sin(angle) * (radius - ringWidth * 0.5))
    let tip = CGPoint(x: rect.minX + s * 0.93, y: rect.minY + s * 0.07)
    let spread = ringWidth * 1.15
    let normal = CGPoint(x: -sin(angle), y: cos(angle))
    let tail = CGMutablePath()
    tail.move(to: CGPoint(x: base.x + normal.x * spread, y: base.y + normal.y * spread))
    tail.addQuadCurve(to: tip, control: CGPoint(x: base.x + (tip.x - base.x) * 0.55 + normal.x * spread * 0.35,
                                                 y: base.y + (tip.y - base.y) * 0.55 + normal.y * spread * 0.35))
    tail.addQuadCurve(to: CGPoint(x: base.x - normal.x * spread, y: base.y - normal.y * spread),
                      control: CGPoint(x: base.x + (tip.x - base.x) * 0.45 - normal.x * spread * 0.55,
                                       y: base.y + (tip.y - base.y) * 0.45 - normal.y * spread * 0.55))
    tail.closeSubpath()
    path.addPath(tail)
    return path
}

func fillMark(_ ctx: CGContext, rect: CGRect, ringWidth: CGFloat) {
    let path = qBubblePath(in: rect, ringWidth: ringWidth)
    // Ring uses even-odd so the hole stays open; the tail overlaps the ring, so fill the two separately.
    let s = rect.width
    let center = CGPoint(x: rect.minX + s * 0.47, y: rect.minY + s * 0.53)
    let radius = s * 0.36
    let donut = CGMutablePath()
    donut.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    let inner = radius - ringWidth
    donut.addEllipse(in: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2))
    ctx.addPath(donut)
    ctx.fillPath(using: .evenOdd)
    // Tail only (the last subpath): rebuild by clipping out the ring's interior.
    ctx.saveGState()
    let hole = CGPath(ellipseIn: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2), transform: nil)
    let clip = CGMutablePath()
    clip.addRect(rect.insetBy(dx: -s, dy: -s))
    clip.addPath(hole)
    ctx.addPath(clip)
    ctx.clip(using: .evenOdd)
    ctx.addPath(path)
    ctx.fillPath(using: .winding)
    ctx.restoreGState()
}

// MARK: - App icon

func appIcon(_ ctx: CGContext, _ size: CGFloat) {
    let scale = size / 1024
    let tile = CGRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let radius = 185 * scale
    let tilePath = CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Drop shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 28 * scale, color: color(0x5A4630, 0.28))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(0xF6F1E7))
    ctx.fillPath()
    ctx.restoreGState()

    // Cream gradient surface.
    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let cream = CGGradient(colorsSpace: nil, colors: [color(0xFDFBF6), color(0xF1E9DA)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(cream, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
    // Soft top sheen.
    let sheen = CGGradient(colorsSpace: nil, colors: [color(0xFFFFFF, 0.55), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(sheen, startCenter: CGPoint(x: tile.midX, y: tile.maxY), startRadius: 0,
                           endCenter: CGPoint(x: tile.midX, y: tile.maxY), endRadius: tile.width * 0.75, options: [])
    ctx.restoreGState()

    // Hairline edge.
    ctx.addPath(tilePath)
    ctx.setStrokeColor(color(0xCBBFA9, 0.55))
    ctx.setLineWidth(max(1, 2 * scale))
    ctx.strokePath()

    // Bronze mark with a gentle gradient and shadow.
    let markRect = tile.insetBy(dx: 150 * scale, dy: 150 * scale)
    let ring = 36 * scale
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6 * scale), blur: 14 * scale, color: color(0x6B4F2A, 0.25))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setFillColor(color(0x9A7644))
    fillMark(ctx, rect: markRect, ringWidth: ring)
    ctx.setBlendMode(.sourceAtop)
    let bronze = CGGradient(colorsSpace: nil, colors: [color(0xBE9A63), color(0x8B6837)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bronze, start: CGPoint(x: 0, y: markRect.maxY), end: CGPoint(x: 0, y: markRect.minY), options: [])
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    // 譯 in deep ink serif, centred in the ring.
    let s = markRect.width
    let center = CGPoint(x: markRect.minX + s * 0.47, y: markRect.minY + s * 0.53)
    let font = NSFont(name: "Songti TC Bold", size: 168 * scale) ?? NSFont.systemFont(ofSize: 168 * scale, weight: .bold)
    let attributed = NSAttributedString(string: "譯", attributes: [.font: font, .foregroundColor: NSColor(cgColor: color(0x2A241F))!])
    let line = CTLineCreateWithAttributedString(attributed)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.textPosition = CGPoint(x: center.x - bounds.midX, y: center.y - bounds.midY)
    CTLineDraw(line, ctx)
}

// MARK: - Menu bar template

func menuBarIcon(_ ctx: CGContext, _ size: CGFloat) {
    let inset = size * 0.04
    ctx.setFillColor(color(0x000000))
    fillMark(ctx, rect: CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2), ringWidth: size * 0.095)
}

func write(_ data: Data, _ path: String) {
    let url = assets.appendingPathComponent(path)
    try! data.write(to: url)
    print("wrote", url.path)
}

for size in [16, 32, 64, 128, 256, 512, 1024] {
    write(render(size: size, draw: appIcon), "AppIcon.appiconset/AppIcon-\(size).png")
}
write(render(size: 18, draw: menuBarIcon), "MenuBarIcon.imageset/MenuBarIcon-18.png")
write(render(size: 36, draw: menuBarIcon), "MenuBarIcon.imageset/MenuBarIcon-36.png")
write(render(size: 54, draw: menuBarIcon), "MenuBarIcon.imageset/MenuBarIcon-54.png")
