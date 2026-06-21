// Generates the launch/splash logo: a white shopping cart with a check badge on
// a transparent background. The splash screen composes this over the green
// gradient and adds the wordmark. Run with: swift tools/make_launch_logo.swift [outPath]
import AppKit

let size = 600.0
let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Marktlotse/Assets.xcassets/LaunchLogo.imageset/LaunchLogo.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Map the 1024-space cart artwork into this canvas (top-left origin).
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)
let scale = size / 1024.0
ctx.scaleBy(x: scale, y: scale)

ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setFillColor(NSColor.white.cgColor)
ctx.setLineWidth(52)
ctx.setLineJoin(.round)
ctx.setLineCap(.round)

// Handle.
ctx.beginPath()
ctx.move(to: CGPoint(x: 205, y: 345))
ctx.addLine(to: CGPoint(x: 320, y: 345))
ctx.strokePath()

// Basket body.
ctx.beginPath()
ctx.move(to: CGPoint(x: 320, y: 345))
ctx.addLine(to: CGPoint(x: 392, y: 455))
ctx.addLine(to: CGPoint(x: 838, y: 455))
ctx.addLine(to: CGPoint(x: 760, y: 685))
ctx.addLine(to: CGPoint(x: 478, y: 685))
ctx.addLine(to: CGPoint(x: 392, y: 455))
ctx.strokePath()

// Vertical grid bars.
for x in stride(from: 478.0, through: 790.0, by: 100.0) {
    ctx.beginPath()
    ctx.move(to: CGPoint(x: x, y: 500))
    ctx.addLine(to: CGPoint(x: x - 30, y: 680))
    ctx.setLineWidth(26)
    ctx.strokePath()
}
ctx.setLineWidth(52)

// Wheels.
for cx in [528.0, 720.0] {
    let r = 46.0
    ctx.fillEllipse(in: CGRect(x: cx - r, y: 760 - r, width: r * 2, height: r * 2))
}

// Check badge.
let badgeCenter = CGPoint(x: 760, y: 300)
let badgeRadius = 132.0
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillEllipse(in: CGRect(x: badgeCenter.x - badgeRadius,
                           y: badgeCenter.y - badgeRadius,
                           width: badgeRadius * 2,
                           height: badgeRadius * 2))

ctx.setStrokeColor(NSColor(red: 0.05, green: 0.52, blue: 0.38, alpha: 1).cgColor)
ctx.setLineWidth(40)
ctx.beginPath()
ctx.move(to: CGPoint(x: badgeCenter.x - 58, y: badgeCenter.y + 6))
ctx.addLine(to: CGPoint(x: badgeCenter.x - 16, y: badgeCenter.y + 50))
ctx.addLine(to: CGPoint(x: badgeCenter.x + 64, y: badgeCenter.y - 48))
ctx.strokePath()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("Failed to create PNG\n".data(using: .utf8)!)
    exit(1)
}
try data.write(to: URL(fileURLWithPath: outPath))
print("Wrote launch logo to \(outPath)")
