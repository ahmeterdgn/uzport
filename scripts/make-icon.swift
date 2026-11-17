// docs/logo.svg'den AppIcon.icns üretir: swift scripts/make-icon.swift Resources/AppIcon.icns
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.icns"
guard let logo = NSImage(contentsOfFile: "docs/logo.svg") else { fatalError("docs/logo.svg okunamadı") }

func render(_ px: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: px / 1024, y: px / 1024)
    // macOS ikon ızgarası: 824x824 gövde, hafif gölge.
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.28).cgColor)
    logo.draw(in: NSRect(x: 100, y: 100, width: 824, height: 824))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let fm = FileManager.default
let iconset = NSTemporaryDirectory() + "AppIcon.iconset"
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! render(CGFloat(base * scale)).representation(using: .png, properties: [:])!
            .write(to: URL(fileURLWithPath: iconset + "/" + name))
    }
}
try! render(1024).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/icon.png"))
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset, "-o", out]
try! p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "ikon yazıldı: \(out)" : "iconutil başarısız")
