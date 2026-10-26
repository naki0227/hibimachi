import SpriteKit

extension IslandScene {
    /// A daytime picture of the whole island (no tint, lamp glows, grid or selection), for the home-screen
    /// widget. `nil` before the scene is on screen.
    func islandPicture(maxWidth: Int = 640) -> CGImage? {
        guard let view else { return nil }
        glowLayer.isHidden = true
        defer { glowLayer.isHidden = false }
        guard let full = view.texture(from: worldLayer)?.cgImage() else { return nil }
        // The texture covers the layer's accumulated frame (top-left origin); the terrain starts at the scene
        // origin. Extra room above for roofs and treetops, a little around for the cliff edges.
        let frame = worldLayer.calculateAccumulatedFrame()
        let scale = Double(full.width) / frame.width
        let map = CGRect(x: 0, y: 0, width: grid.mapSize.width, height: grid.mapSize.height).insetBy(dx: -12, dy: -12)
        let island = CGRect(x: map.minX, y: map.minY, width: map.width, height: map.height + 60)
        let crop = CGRect(
            x: (island.minX - frame.minX) * scale, y: (frame.maxY - island.maxY) * scale,
            width: island.width * scale, height: island.height * scale)
        guard let cropped = full.cropping(to: crop.integral) else { return nil }
        return cropped.width > maxWidth ? cropped.resized(width: maxWidth) : cropped
    }
}

extension CGImage {
    /// Nearest-neighbour downscale, keeping the pixel art crisp.
    fileprivate func resized(width newWidth: Int) -> CGImage? {
        let newHeight = max(1, height * newWidth / width)
        guard
            let context = CGContext(
                data: nil, width: newWidth, height: newHeight, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .none
        context.draw(self, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }
}
