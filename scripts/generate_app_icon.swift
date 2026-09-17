import AppKit
import CoreGraphics
import Foundation

// Create a high-quality 1024x1024 macOS app icon
func renderMasterIcon(size: CGFloat = 1024) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    
    // Scale factor relative to 1024
    let s = size / 1024.0
    
    // Apple macOS Icon standard grid:
    // Base squircle: 824x824, centered at (512, 512), corner radius 185
    let squircleRect = CGRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let cornerRadius = 185.0 * s
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    // 1. Drop shadow beneath squircle
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -18 * s),
        blur: 32 * s,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.38)
    )
    ctx.addPath(squirclePath)
    ctx.setFillColor(CGColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()
    
    // 2. Base Squircle with Dark Blue-Navy Gradient
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.07, green: 0.11, blue: 0.20, alpha: 1.0), // Deep space navy
        CGColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0), // Midnight obsidian
        CGColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 1.0)
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.6, 1.0]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(
            bgGradient,
            start: CGPoint(x: squircleRect.midX, y: squircleRect.maxY),
            end: CGPoint(x: squircleRect.midX, y: squircleRect.minY),
            options: []
        )
    }
    
    // 3. Subtle background radial glow behind waveform (Smurf Blue + Emerald Green)
    if let glowGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 0.25), // Blue glow
            CGColor(red: 0.17, green: 0.76, blue: 0.41, alpha: 0.12), // Green glow
            CGColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        ] as CFArray,
        locations: [0.0, 0.5, 1.0]
    ) {
        ctx.drawRadialGradient(
            glowGradient,
            startCenter: CGPoint(x: 512 * s, y: 512 * s),
            startRadius: 20 * s,
            endCenter: CGPoint(x: 512 * s, y: 512 * s),
            endRadius: 360 * s,
            options: []
        )
    }
    
    // 4. Concentric circular soundwave guide rings
    ctx.setLineWidth(2.5 * s)
    for radius in [180.0 * s, 260.0 * s, 330.0 * s] {
        ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.04))
        ctx.strokeEllipse(in: CGRect(
            x: (512 * s) - radius,
            y: (512 * s) - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }
    
    // 5. Stylized Audio Waveform / Equalizer Bars
    // We draw 9 vertical dynamic equalizer bars with pill shapes and glowing gradient
    let barCount = 9
    let barWidth = 36.0 * s
    let barSpacing = 28.0 * s
    let totalBarsWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
    let startX = (1024 * s - totalBarsWidth) / 2.0
    
    // Heights for dynamic musical waveform contour:
    let barHeights: [CGFloat] = [
        130.0 * s,
        240.0 * s,
        370.0 * s,
        480.0 * s,
        560.0 * s, // Center peak
        450.0 * s,
        340.0 * s,
        220.0 * s,
        140.0 * s
    ]
    
    for i in 0..<barCount {
        let x = startX + CGFloat(i) * (barWidth + barSpacing)
        let height = barHeights[i]
        let y = (512 * s) - (height / 2.0)
        let barRect = CGRect(x: x, y: y, width: barWidth, height: height)
        let barPillPath = CGPath(roundedRect: barRect, cornerWidth: barWidth / 2.0, cornerHeight: barWidth / 2.0, transform: nil)
        
        ctx.saveGState()
        
        // Glow shadow for each bar
        let t = CGFloat(i) / CGFloat(barCount - 1)
        let glowColor = CGColor(
            red: (1 - t) * 0.05 + t * 0.17,
            green: (1 - t) * 0.65 + t * 0.85,
            blue: (1 - t) * 1.0 + t * 0.45,
            alpha: 0.6
        )
        ctx.setShadow(offset: .zero, blur: 14 * s, color: glowColor)
        
        // Gradient from Smurf Electric Blue at bottom to Neon Green at top
        ctx.addPath(barPillPath)
        ctx.clip()
        
        let barColors = [
            CGColor(red: 0.05, green: 0.58, blue: 1.0, alpha: 1.0), // Smurf Blue
            CGColor(red: 0.10, green: 0.72, blue: 0.82, alpha: 1.0), // Cyan transition
            CGColor(red: 0.17, green: 0.88, blue: 0.45, alpha: 1.0)  // Emerald Green
        ] as CFArray
        
        if let barGradient = CGGradient(colorsSpace: colorSpace, colors: barColors, locations: [0.0, 0.5, 1.0]) {
            ctx.drawLinearGradient(
                barGradient,
                start: CGPoint(x: x, y: y),
                end: CGPoint(x: x, y: y + height),
                options: []
            )
        }
        
        // Inner highlight on top edge of pill
        ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.4))
        ctx.setLineWidth(1.5 * s)
        let highlightPath = CGMutablePath()
        highlightPath.addArc(
            center: CGPoint(x: x + barWidth / 2.0, y: y + height - barWidth / 2.0),
            radius: (barWidth / 2.0) - 1.5 * s,
            startAngle: 0,
            endAngle: .pi,
            clockwise: false
        )
        ctx.addPath(highlightPath)
        ctx.strokePath()
        
        ctx.restoreGState()
    }
    
    // 6. Horizontal Center Wave Line connecting the bars (sine curve accent)
    ctx.saveGState()
    let wavePath = CGMutablePath()
    let wavePoints: [CGPoint] = [
        CGPoint(x: 180 * s, y: 512 * s),
        CGPoint(x: 280 * s, y: 560 * s),
        CGPoint(x: 390 * s, y: 460 * s),
        CGPoint(x: 512 * s, y: 580 * s),
        CGPoint(x: 630 * s, y: 440 * s),
        CGPoint(x: 740 * s, y: 560 * s),
        CGPoint(x: 844 * s, y: 512 * s)
    ]
    
    wavePath.move(to: wavePoints[0])
    for i in 1..<wavePoints.count {
        let prev = wavePoints[i - 1]
        let curr = wavePoints[i]
        let midX = (prev.x + curr.x) / 2.0
        wavePath.addCurve(
            to: curr,
            control1: CGPoint(x: midX, y: prev.y),
            control2: CGPoint(x: midX, y: curr.y)
        )
    }
    
    ctx.setLineWidth(3.0 * s)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.28))
    ctx.setShadow(offset: .zero, blur: 8 * s, color: CGColor(red: 0.17, green: 0.88, blue: 0.45, alpha: 0.5))
    ctx.addPath(wavePath)
    ctx.strokePath()
    ctx.restoreGState()
    
    // 7. Subtle Bevel / Inner Stroke on the Squircle rim (macOS Big Sur+ style)
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.setLineWidth(2.5 * s)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.18))
    ctx.strokePath()
    ctx.restoreGState()
    
    // 8. Subtle top highlight curve on squircle
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    if let topHighlight = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.12),
            CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
        ] as CFArray,
        locations: [0.0, 1.0]
    ) {
        ctx.drawLinearGradient(
            topHighlight,
            start: CGPoint(x: squircleRect.midX, y: squircleRect.maxY),
            end: CGPoint(x: squircleRect.midX, y: squircleRect.maxY - 140 * s),
            options: []
        )
    }
    ctx.restoreGState()
    
    ctx.restoreGState()
    image.unlockFocus()
    
    return image
}

// Function to export NSImage to PNG data at target pixel dimensions
func savePNG(image: NSImage, targetSize: Int, to url: URL) throws {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: targetSize,
        pixelsHigh: targetSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: targetSize, height: targetSize)
    
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(
        in: NSRect(x: 0, y: 0, width: targetSize, height: targetSize),
        from: NSRect(origin: .zero, size: image.size),
        operation: .copy,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()
    
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG"])
    }
    try pngData.write(to: url)
}

// Main execution
let fileManager = FileManager.default
let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconsetURL = currentDir.appendingPathComponent("AppIcon.iconset")
let resourcesURL = currentDir.appendingPathComponent("Resources")

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

print("🎨 Rendering master 1024x1024 SmurfAudio macOS app icon...")
let masterImage = renderMasterIcon(size: 1024)

// Standard Apple iconset resolutions
let iconSizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for item in iconSizes {
    let fileURL = iconsetURL.appendingPathComponent(item.name)
    try savePNG(image: masterImage, targetSize: item.px, to: fileURL)
    print("  ✓ Created \(item.name) (\(item.px)x\(item.px))")
}

// Also save high-res master PNG in Resources
let masterPNGURL = resourcesURL.appendingPathComponent("AppIcon.png")
try savePNG(image: masterImage, targetSize: 1024, to: masterPNGURL)
print("  ✓ Created Resources/AppIcon.png (1024x1024)")

// Compile with iconutil
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")
print("🔨 Compiling AppIcon.icns via iconutil...")

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    print("✅ Successfully generated \(icnsURL.path)!")
    try? fileManager.removeItem(at: iconsetURL)
} else {
    print("❌ iconutil failed with status: \(process.terminationStatus)")
    exit(process.terminationStatus)
}
