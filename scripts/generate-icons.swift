// Draws Notchy's app icon and menu bar glyph into Notchy/Resources/Assets.xcassets.
// Run from the repo root: swift scripts/generate-icons.swift
import AppKit

let assets = "Notchy/Resources/Assets.xcassets"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Renders at `pixels`², drawing on a 1024-unit grid (`s` = pixels / 1024).
func render(_ pixels: Int, _ draw: (CGContext, CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSGraphicsContext.current!.cgContext, CGFloat(pixels) / 1024)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

/// Dark rounded square (Apple's 824/1024 icon grid) with a light "island" capsule near the top.
func appIcon(_ pixels: Int) -> Data {
    render(pixels) { ctx, s in
        let body = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
        let shape = roundedRect(body, 185 * s)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 28 * s, color: color(0x000000, 0.35))
        ctx.addPath(shape)
        ctx.setFillColor(color(0x0B0B0D))
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(shape)
        ctx.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [color(0x2A2A2E), color(0x0B0B0D)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])
        ctx.restoreGState()

        let island = CGRect(x: body.midX - 190 * s, y: body.maxY - 250 * s, width: 380 * s, height: 112 * s)
        ctx.addPath(roundedRect(island, 56 * s))
        ctx.setFillColor(color(0xF5F5F7))
        ctx.fillPath()
    }
}

/// Template glyph (black on transparent): a screen outline with a filled island at the top.
func menuBarGlyph(_ pixels: Int) -> Data {
    render(pixels) { ctx, s in
        let screen = CGRect(x: 96 * s, y: 176 * s, width: 832 * s, height: 672 * s)
        ctx.addPath(roundedRect(screen.insetBy(dx: 40 * s, dy: 40 * s), 150 * s))
        ctx.setStrokeColor(color(0x000000))
        ctx.setLineWidth(80 * s)
        ctx.strokePath()

        let island = CGRect(x: 512 * s - 170 * s, y: screen.maxY - 250 * s, width: 340 * s, height: 110 * s)
        ctx.addPath(roundedRect(island, 55 * s))
        ctx.setFillColor(color(0x000000))
        ctx.fillPath()
    }
}

func write(_ data: Data, _ path: String) {
    try! FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent,
                                             withIntermediateDirectories: true)
    try! data.write(to: URL(fileURLWithPath: path))
}

func writeJSON(_ object: Any, _ path: String) {
    write(try! JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]), path)
}

let info = ["author": "xcode", "version": 1] as [String: Any]
writeJSON(["info": info], "\(assets)/Contents.json")

var iconImages: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        write(appIcon(points * scale), "\(assets)/AppIcon.appiconset/\(name)")
        iconImages.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
    }
}
writeJSON(["images": iconImages, "info": info], "\(assets)/AppIcon.appiconset/Contents.json")

write(menuBarGlyph(18), "\(assets)/MenuBarIcon.imageset/menubar.png")
write(menuBarGlyph(36), "\(assets)/MenuBarIcon.imageset/menubar@2x.png")
writeJSON([
    "images": [
        ["filename": "menubar.png", "idiom": "universal", "scale": "1x"],
        ["filename": "menubar@2x.png", "idiom": "universal", "scale": "2x"],
    ],
    "info": info,
    "properties": ["template-rendering-intent": "template"],
], "\(assets)/MenuBarIcon.imageset/Contents.json")

print("Icons written to \(assets)")
