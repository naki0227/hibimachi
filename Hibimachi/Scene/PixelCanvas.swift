import CoreGraphics
import SpriteKit

/// A tiny drawing surface for code-authored pixel art. Antialiasing is off and the texture uses nearest
/// filtering, so shapes come out with hard pixel edges. Coordinates are in art pixels, origin bottom-left.
final class PixelCanvas {
    let width: Int
    let height: Int
    private let context: CGContext

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { preconditionFailure("Could not create a \(width)x\(height) bitmap context") }
        context.setShouldAntialias(false)
        context.setAllowsAntialiasing(false)
        context.interpolationQuality = .none
        self.context = context
    }

    func rect(_ color: SKColor, _ x: Int, _ y: Int, _ w: Int, _ h: Int) {
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    func pixel(_ color: SKColor, _ x: Int, _ y: Int) {
        rect(color, x, y, 1, 1)
    }

    func polygon(_ color: SKColor, _ points: [(Double, Double)]) {
        guard let first = points.first else { return }
        context.setFillColor(color.cgColor)
        context.beginPath()
        context.move(to: CGPoint(x: first.0, y: first.1))
        for point in points.dropFirst() { context.addLine(to: CGPoint(x: point.0, y: point.1)) }
        context.closePath()
        context.fillPath()
    }

    func ellipse(_ color: SKColor, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
    }

    func line(_ color: SKColor, from: (Double, Double), to: (Double, Double)) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1)
        context.beginPath()
        context.move(to: CGPoint(x: from.0, y: from.1))
        context.addLine(to: CGPoint(x: to.0, y: to.1))
        context.strokePath()
    }

    /// Soft radial light for glows (the only non-pixel-art drawing; used with additive blending).
    func radialGlow(_ color: SKColor) {
        let colors = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
        guard
            let gradient = CGGradient(
                colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])
        else { return }
        let center = CGPoint(x: Double(width) / 2, y: Double(height) / 2)
        context.drawRadialGradient(
            gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: Double(min(width, height)) / 2,
            options: [])
    }

    func makeImage() -> CGImage {
        guard let image = context.makeImage() else { preconditionFailure("Could not render pixel canvas") }
        return image
    }

    func makeTexture() -> SKTexture {
        let texture = SKTexture(cgImage: makeImage())
        texture.filteringMode = .nearest
        return texture
    }
}

/// Deterministic hash noise so the island's grass speckles and flowers look the same every launch.
enum PixelNoise {
    static func value(_ x: Int, _ y: Int, _ salt: Int = 0) -> Int {
        var h = UInt64(bitPattern: Int64(x &* 73_856_093 ^ y &* 19_349_663 ^ salt &* 83_492_791))
        h ^= h >> 33
        h &*= 0xFF51_AFD7_ED55_8CCD
        h ^= h >> 33
        return Int(h % 1_000)
    }
}
