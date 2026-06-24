import AppKit

// Renders a simple, original OpenCrashCart app icon (no vendor branding) to a 1024×1024 PNG.
// Usage: swift packaging/makeicon.swift <output.png>

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
let full = CGRect(x: 0, y: 0, width: size, height: size)

// Rounded-rect near-black background with a subtle grey gradient.
let bg = CGPath(roundedRect: full.insetBy(dx: 70, dy: 70), cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.addPath(bg); ctx.clip()
let colors = [
    NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1).cgColor,
    NSColor(srgbRed: 0.05, green: 0.05, blue: 0.06, alpha: 1).cgColor,
] as CFArray
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
ctx.drawLinearGradient(gradient, start: CGPoint(x: 120, y: 900), end: CGPoint(x: 900, y: 120), options: [])
ctx.restoreGState()

// Highlighter accents.
let orange = NSColor(srgbRed: 1.00, green: 0.55, blue: 0.13, alpha: 1).cgColor
let green  = NSColor(srgbRed: 0.24, green: 0.89, blue: 0.52, alpha: 1).cgColor
let pink   = NSColor(srgbRed: 1.00, green: 0.32, blue: 0.67, alpha: 1).cgColor

// Monitor screen outline — pink as the lead accent.
let screen = CGRect(x: 285, y: 380, width: 454, height: 320)
let screenPath = CGPath(roundedRect: screen, cornerWidth: 34, cornerHeight: 34, transform: nil)
ctx.setLineWidth(36)
ctx.setStrokeColor(pink)
ctx.addPath(screenPath); ctx.strokePath()

// Stand — pink.
ctx.setFillColor(pink)
ctx.fill(CGRect(x: 472, y: 312, width: 80, height: 80))
ctx.fill(CGRect(x: 392, y: 292, width: 240, height: 38))

// "Terminal" lines on the screen — orange + green secondary accents, plus a pink cursor.
ctx.setFillColor(orange)
ctx.fill(CGRect(x: 360, y: 540, width: 250, height: 30))
ctx.setFillColor(green)
ctx.fill(CGRect(x: 360, y: 470, width: 160, height: 30))
ctx.setFillColor(pink)
ctx.fill(CGRect(x: 540, y: 470, width: 34, height: 30))

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("icon render failed\n".utf8)); exit(1)
}
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
