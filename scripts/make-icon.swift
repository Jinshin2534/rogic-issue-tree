// アプリアイコン（Resources/AppIcon.icns）を生成する: swift scripts/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let s = CGFloat(px) / 1024
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: s, y: s)

    // 背景（macOS 標準の角丸スクエア）
    let base = CGRect(x: 100, y: 100, width: 824, height: 824)
    let basePath = CGPath(roundedRect: base, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(basePath)
    ctx.setFillColor(CGColor(srgbRed: 0.18, green: 0.35, blue: 0.80, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(basePath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: nil, colors: [
        CGColor(srgbRed: 0.30, green: 0.52, blue: 0.95, alpha: 1),
        CGColor(srgbRed: 0.13, green: 0.27, blue: 0.68, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])
    ctx.restoreGState()

    // ツリー
    let w: CGFloat = 176, h: CGFloat = 78
    let cols: [CGFloat] = [176, 424, 672]
    func box(_ col: Int, _ cy: CGFloat) -> CGRect { CGRect(x: cols[col], y: cy - h / 2, width: w, height: h) }
    let root = box(0, 512)
    let mids = [box(1, 704), box(1, 512), box(1, 320)]
    let leaves = [box(2, 704), box(2, 376), box(2, 264)]

    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.85))
    ctx.setLineWidth(12)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    func connect(_ parent: CGRect, _ children: [CGRect]) {
        let midX = parent.maxX + (cols[1] - cols[0] - w) / 2
        ctx.move(to: CGPoint(x: parent.maxX, y: parent.midY))
        ctx.addLine(to: CGPoint(x: midX, y: parent.midY))
        let ys = children.map(\.midY) + [parent.midY]
        ctx.move(to: CGPoint(x: midX, y: ys.min()!))
        ctx.addLine(to: CGPoint(x: midX, y: ys.max()!))
        for c in children {
            ctx.move(to: CGPoint(x: midX, y: c.midY))
            ctx.addLine(to: CGPoint(x: c.minX, y: c.midY))
        }
        ctx.strokePath()
    }
    connect(root, mids)
    connect(mids[0], [leaves[0]])
    connect(mids[2], [leaves[1], leaves[2]])

    func fill(_ r: CGRect, _ color: CGColor) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 12, color: CGColor(gray: 0, alpha: 0.25))
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: 20, cornerHeight: 20, transform: nil))
        ctx.setFillColor(color)
        ctx.fillPath()
        ctx.restoreGState()
    }
    let white = CGColor(gray: 1, alpha: 1)
    ([root] + mids + leaves.dropFirst()).forEach { fill($0, white) }
    fill(leaves[0], CGColor(srgbRed: 1.0, green: 0.45, blue: 0.38, alpha: 1)) // 深掘りの先

    // ノード内の文字に見立てた線
    ctx.setLineWidth(10)
    for r in [root] + mids + leaves {
        let isAccent = r == leaves[0]
        ctx.setStrokeColor(isAccent ? CGColor(gray: 1, alpha: 0.9) : CGColor(srgbRed: 0.13, green: 0.27, blue: 0.68, alpha: 0.45))
        ctx.move(to: CGPoint(x: r.minX + 26, y: r.midY + 12))
        ctx.addLine(to: CGPoint(x: r.maxX - 26, y: r.midY + 12))
        ctx.move(to: CGPoint(x: r.minX + 26, y: r.midY - 12))
        ctx.addLine(to: CGPoint(x: r.maxX - 70, y: r.midY - 12))
        ctx.strokePath()
    }

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    try! render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try! render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try! render(1024).write(to: URL(fileURLWithPath: "Resources/AppIcon-1024.png"))
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! task.run()
task.waitUntilExit()
print("Resources/AppIcon.icns")
