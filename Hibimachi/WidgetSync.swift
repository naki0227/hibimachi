import Foundation
import ImageIO
import UniformTypeIdentifiers
import WidgetKit

/// Keeps the home-screen widget in step with the app: writes the island picture to the shared container and
/// asks WidgetKit to re-read the save. Without an App Group (unsigned builds) this does nothing.
@MainActor
enum WidgetSync {
    static func exportIsland(_ image: CGImage?) {
        guard let image, let url = SharedContainer.islandImageURL,
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image, nil)
        // A failed write only leaves the previous picture in the widget.
        _ = CGImageDestinationFinalize(destination)
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
