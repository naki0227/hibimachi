/// Keeps the camera usable on small screens: zoom limits and a pan clamp so the island never leaves the view.
///
/// `scale` follows SKCameraNode semantics: visible area = viewport size × scale (larger = zoomed out).
public struct CameraBounds: Equatable, Sendable {
    public let mapSize: SceneSize
    public let minScale: Double
    public let maxScale: Double
    /// Extra scene units the player may pan beyond the map edge, so edge tiles are not hidden under the HUD.
    public let margin: Double

    public init(mapSize: SceneSize, minScale: Double = 0.35, maxScale: Double = 2.0, margin: Double = 48) {
        precondition(minScale > 0 && minScale <= maxScale, "invalid scale range")
        self.mapSize = mapSize
        self.minScale = minScale
        self.maxScale = maxScale
        self.margin = margin
    }

    public func clampScale(_ scale: Double) -> Double {
        min(max(scale, minScale), maxScale)
    }

    /// Scale that fits the whole map (plus margin) into `viewport`, within the allowed range.
    public func fittingScale(for viewport: SceneSize) -> Double {
        guard viewport.width > 0, viewport.height > 0 else { return maxScale }
        let needed = max(
            (mapSize.width + margin * 2) / viewport.width,
            (mapSize.height + margin * 2) / viewport.height
        )
        return clampScale(needed)
    }

    public func clampPosition(_ position: ScenePoint, viewport: SceneSize, scale: Double) -> ScenePoint {
        let visible = SceneSize(width: viewport.width * scale, height: viewport.height * scale)
        return ScenePoint(
            x: clampAxis(position.x, visible: visible.width, length: mapSize.width),
            y: clampAxis(position.y, visible: visible.height, length: mapSize.height)
        )
    }

    private func clampAxis(_ value: Double, visible: Double, length: Double) -> Double {
        let lower = visible / 2 - margin
        let upper = length - visible / 2 + margin
        // When the view is wider than map + margins, keep the map centered instead of letting it drift.
        guard lower <= upper else { return length / 2 }
        return min(max(value, lower), upper)
    }
}
