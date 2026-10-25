import HibimachiCore
import SpriteKit
import UIKit

/// Touch handling. Rules for which gesture does what (kept simple to avoid mis-placement on small phones):
/// - Tap: browse → select the object under the finger; editing → move the preview there (never commits).
/// - One/two-finger drag: pans the camera, except a drag that *starts on the preview* moves the preview.
/// - Pinch: zoom, clamped so the island stays visible.
/// Committing always requires the explicit SwiftUI "ここに置く" button.
extension IslandScene: UIGestureRecognizerDelegate {
    enum PanMode {
        case none
        case camera
        case preview
    }

    func installGestures(on view: SKView) {
        removeGestures(from: view)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 2
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        for recognizer in [tap, pan, pinch] {
            recognizer.delegate = self
            view.addGestureRecognizer(recognizer)
        }
        gestureRecognizersInstalled = [tap, pan, pinch]
    }

    func removeGestures(from view: SKView) {
        gestureRecognizersInstalled.forEach(view.removeGestureRecognizer)
        gestureRecognizersInstalled = []
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        // Pan + pinch together feel natural for two-finger navigation.
        !(gestureRecognizer is UITapGestureRecognizer) && !(other is UITapGestureRecognizer)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let point = convertPoint(fromView: recognizer.location(in: view))
        if let kind = store.previewKind {
            store.setPreviewOrigin(geometry.origin(for: kind.footprint, centeredAt: point.scenePoint))
            return
        }
        guard let tile = geometry.tile(at: point.scenePoint) else {
            store.select(nil)
            return
        }
        if tile == store.world.creature.position {
            creatureNode.flash("!", reduceMotion: reduceMotion)
        }
        store.selectObject(at: tile)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        switch recognizer.state {
        case .began:
            let point = convertPoint(fromView: recognizer.location(in: view)).scenePoint
            panMode = isOnPreview(point) && recognizer.numberOfTouches == 1 ? .preview : .camera
        case .changed:
            switch panMode {
            case .preview:
                guard let kind = store.previewKind else { return }
                let point = convertPoint(fromView: recognizer.location(in: view)).scenePoint
                store.setPreviewOrigin(geometry.origin(for: kind.footprint, centeredAt: point))
            case .camera:
                let translation = recognizer.translation(in: view)
                cameraNode.position.x -= translation.x * cameraNode.xScale
                cameraNode.position.y += translation.y * cameraNode.yScale
                recognizer.setTranslation(.zero, in: view)
                clampCamera()
            case .none:
                break
            }
        default:
            panMode = .none
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard recognizer.state == .changed, recognizer.scale > 0 else { return }
        let scale = bounds.clampScale(Double(cameraNode.xScale) / Double(recognizer.scale))
        cameraNode.setScale(CGFloat(scale))
        recognizer.scale = 1
        clampCamera()
    }

    private func isOnPreview(_ point: ScenePoint) -> Bool {
        guard let kind = store.previewKind, let origin = store.previewOrigin, let tile = geometry.tile(at: point)
        else { return false }
        // One tile of slack makes the ghost easy to grab with a thumb.
        return kind.footprint.tiles(at: origin).contains { $0.chebyshevDistance(to: tile) <= 1 }
    }

    /// Fits the whole island on screen, centered.
    func resetCamera() {
        cameraNode.setScale(CGFloat(bounds.fittingScale(for: viewportSize)))
        cameraNode.position = CGPoint(x: geometry.mapSize.width / 2, y: geometry.mapSize.height / 2)
        clampCamera()
    }

    func clampCamera() {
        let clamped = bounds.clampPosition(
            cameraNode.position.scenePoint, viewport: viewportSize, scale: Double(cameraNode.xScale))
        cameraNode.position = clamped.cgPoint
    }

    private var viewportSize: SceneSize {
        SceneSize(width: Double(size.width), height: Double(size.height))
    }
}
