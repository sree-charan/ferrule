// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Sree Charan

// Draws Ferrule's brand masters from one geometry:
// - Resources/Brand/logo.png: the mark in black on transparency, which
//   Tools/MakeIcon.swift trims into the menu bar glyph and BrandMark
// - Resources/Brand/AppIcon-Default.png: the flat icon the .icns falls back to
// - Resources/Brand/AppIcon.icon/Assets/ferrule-brandmark.svg: the mark layer
//   of the adaptive icon
//
// The mark is a hex nut seen head-on, flats top and bottom, with a round bore
// and one notch cut into the top flat. Run from the repository root:
//   swift Tools/MakeBrand.swift

import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

/// Safety orange, the one accent.
let accent = NSColor(srgbRed: 0xF2 / 255, green: 0x60 / 255, blue: 0x1C / 255, alpha: 1)
/// Graphite plate behind the mark.
let plate = NSColor(srgbRed: 0x1C / 255, green: 0x1D / 255, blue: 0x1B / 255, alpha: 1)

/// Mark geometry for a nut of circumradius `r` centred on the origin, y up.
struct Nut {
    let r: CGFloat
    var apothem: CGFloat { r * sqrt(3) / 2 }
    var bore: CGFloat { r * 0.42 }
    var notchWidth: CGFloat { r * 0.30 }
    var notchDepth: CGFloat { r * 0.17 }

    /// Outline vertices, counter-clockwise from the right corner, with the
    /// notch inserted into the top flat.
    var outline: [CGPoint] {
        let h = apothem, w = notchWidth / 2, d = notchDepth
        return [
            CGPoint(x: r, y: 0),
            CGPoint(x: r / 2, y: h),
            CGPoint(x: w, y: h), CGPoint(x: w, y: h - d),
            CGPoint(x: -w, y: h - d), CGPoint(x: -w, y: h),
            CGPoint(x: -r / 2, y: h),
            CGPoint(x: -r, y: 0),
            CGPoint(x: -r / 2, y: -h),
            CGPoint(x: r / 2, y: -h),
        ]
    }

    func path(center: CGPoint) -> NSBezierPath {
        let path = NSBezierPath()
        path.windingRule = .evenOdd
        for (i, p) in outline.enumerated() {
            let q = CGPoint(x: center.x + p.x, y: center.y + p.y)
            if i == 0 { path.move(to: q) } else { path.line(to: q) }
        }
        path.close()
        path.appendOval(in: CGRect(x: center.x - bore, y: center.y - bore,
                                   width: bore * 2, height: bore * 2))
        return path
    }

    /// The same shape as SVG path data in a viewBox whose origin is top-left.
    func svgPath(center: CGPoint) -> String {
        func f(_ v: CGFloat) -> String { String(format: "%.2f", v) }
        var d = ""
        for (i, p) in outline.enumerated() {
            d += (i == 0 ? "M" : "L") + "\(f(center.x + p.x)) \(f(center.y - p.y)) "
        }
        d += "Z "
        d += "M\(f(center.x + bore)) \(f(center.y)) "
        d += "A\(f(bore)) \(f(bore)) 0 1 0 \(f(center.x - bore)) \(f(center.y)) "
        d += "A\(f(bore)) \(f(bore)) 0 1 0 \(f(center.x + bore)) \(f(center.y)) Z"
        return d
    }
}

func render(_ px: Int, draw: (CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func write(_ data: Data, _ relative: String) {
    let url = root.appendingPathComponent(relative)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    try! data.write(to: url)
    print("wrote \(relative)")
}

// The mark alone, black on transparency, filling most of the canvas.
write(render(1024) { size in
    NSColor.black.setFill()
    Nut(r: size * 0.46).path(center: CGPoint(x: size / 2, y: size / 2)).fill()
}, "Resources/Brand/logo.png")

// The flat icon: a graphite plate on the macOS icon grid (an 824 pt rounded
// square inset 100 pt), a machined rim light along the top edge, and the
// orange nut with a short contact shadow.
write(render(1024) { size in
    let unit = size / 1024
    let tile = CGRect(x: 100 * unit, y: 100 * unit, width: 824 * unit, height: 824 * unit)
    let radius = 185 * unit
    let shape = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

    NSGraphicsContext.saveGraphicsState()
    let drop = NSShadow()
    drop.shadowColor = NSColor.black.withAlphaComponent(0.35)
    drop.shadowBlurRadius = 18 * unit
    drop.shadowOffset = NSSize(width: 0, height: -8 * unit)
    drop.set()
    plate.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    // The rim light: a hairline along the top edge and into its corners.
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(rect: CGRect(x: 0, y: tile.maxY - radius * 0.6, width: size, height: size)).addClip()
    let rim = NSBezierPath(roundedRect: tile.insetBy(dx: 2 * unit, dy: 2 * unit),
                           xRadius: radius - 2 * unit, yRadius: radius - 2 * unit)
    rim.lineWidth = 3 * unit
    NSColor.white.withAlphaComponent(0.12).setStroke()
    rim.stroke()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    let contact = NSShadow()
    contact.shadowColor = NSColor.black.withAlphaComponent(0.45)
    contact.shadowBlurRadius = 10 * unit
    contact.shadowOffset = NSSize(width: 0, height: -6 * unit)
    contact.set()
    accent.setFill()
    Nut(r: 300 * unit).path(center: CGPoint(x: size / 2, y: size / 2)).fill()
    NSGraphicsContext.restoreGraphicsState()
}, "Resources/Brand/AppIcon-Default.png")

// The adaptive icon's mark layer. Icon Composer supplies the plate, glass and
// shadows; the layer is only the orange shape.
let svgSize: CGFloat = 640
let svg = """
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="\(Int(svgSize))" height="\(Int(svgSize))" viewBox="0 0 \(Int(svgSize)) \(Int(svgSize))">
  <path fill="#F2601C" fill-rule="evenodd" d="\(Nut(r: svgSize * 0.46).svgPath(center: CGPoint(x: svgSize / 2, y: svgSize / 2)))"/>
</svg>

"""
write(Data(svg.utf8), "Resources/Brand/AppIcon.icon/Assets/ferrule-brandmark.svg")
