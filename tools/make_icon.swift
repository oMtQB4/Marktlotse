// Generates the 1024x1024 app icon: a shopping cart with a check badge on a
// green gradient. Run with: swift tools/make_icon.swift [outPath]
import AppKit

let size = 1024.0
let outPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Marktlotse/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

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

let rect = CGRect(x: 0, y: 0, width: size, height: size)

// Background: diagonal green gradient with a brighter top-left.
let bgColors = [
    NSColor(red: 0.10, green: 0.72, blue: 0.52, alpha: 1).cgColor,
    NSColor(red: 0.00, green: 0.45, blue: 0.33, alpha: 1).cgColor
] as CFArray
let bgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                            colors: bgColors,
                            locations: [0, 1])!
ctx.drawLinearGradient(bgGradient,
                       start: CGPoint(x: 0, y: size),
                       end: CGPoint(x: size, y: 0),
                       options: [])

// Soft radial highlight behind the cart for depth.
let glowColors = [
    NSColor(white: 1, alpha: 0.16).cgColor,
    NSColor(white: 1, alpha: 0.0).cgColor
] as CFArray
let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: glowColors,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow,
                       startCenter: CGPoint(x: size * 0.5, y: size * 0.56),
                       startRadius: 0,
                       endCenter: CGPoint(x: size * 0.5, y: size * 0.56),
                       endRadius: size * 0.5,
                       options: [])

// Top-left origin coordinate system for intuitive drawing coordinates.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

// Subtle drop shadow under the cart artwork.
ctx.setShadow(offset: CGSize(width: 0, height: -10),
              blur: 36,
              color: NSColor(white: 0, alpha: 0.18).cgColor)

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

// Basket body (open trapezoid: wide top rail, narrower bottom).
ctx.beginPath()
ctx.move(to: CGPoint(x: 320, y: 345))
ctx.addLine(to: CGPoint(x: 392, y: 455))   // diagonal into top-back corner
ctx.addLine(to: CGPoint(x: 838, y: 455))   // top rail
ctx.addLine(to: CGPoint(x: 760, y: 685))   // front side
ctx.addLine(to: CGPoint(x: 478, y: 685))   // bottom rail
ctx.addLine(to: CGPoint(x: 392, y: 455))   // back side up to top-back corner
ctx.strokePath()

// Vertical grid bars inside the basket.
ctx.setShadow(offset: .zero, blur: 0, color: nil)
for x in stride(from: 478.0, through: 790.0, by: 100.0) {
    let topX = x
    let bottomX = x - 30   // slight inward slant matching the trapezoid
    ctx.beginPath()
    ctx.move(to: CGPoint(x: topX, y: 500))
    ctx.addLine(to: CGPoint(x: bottomX, y: 680))
    ctx.setLineWidth(26)
    ctx.strokePath()
}
ctx.setLineWidth(52)

// Wheels.
for cx in [528.0, 720.0] {
    let r = 46.0
    ctx.fillEllipse(in: CGRect(x: cx - r, y: 760 - r, width: r * 2, height: r * 2))
}

// Check badge in the upper-right, suggesting a ticked-off shopping list.
let badgeCenter = CGPoint(x: 760, y: 300)
let badgeRadius = 132.0
ctx.setShadow(offset: CGSize(width: 0, height: -8),
              blur: 24,
              color: NSColor(white: 0, alpha: 0.20).cgColor)
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillEllipse(in: CGRect(x: badgeCenter.x - badgeRadius,
                           y: badgeCenter.y - badgeRadius,
                           width: badgeRadius * 2,
                           height: badgeRadius * 2))
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Green checkmark inside the badge.
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
print("Wrote icon to \(outPath)")
