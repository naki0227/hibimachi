import Foundation
import HibimachiStorage
import ImageIO

/// Files the app and the home-screen widget both read: the save and a picture of the island.
///
/// They live in the App Group container. When the group is not available (unsigned CI builds, or a developer
/// account without the group yet), the app keeps its own folder and the widget shows its "open the app" state.
enum SharedContainer {
    static let appGroupID = "group.dev.naki0227.hibimachi"
    static let saveFolder = "Hibimachi"

    static var groupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static var saveDirectory: URL? { groupURL?.appendingPathComponent(saveFolder, isDirectory: true) }
    static var islandImageURL: URL? { groupURL?.appendingPathComponent("widget-island.png") }

    /// The widget's view of the save (read with `peek`, never quarantined or created).
    static var sharedRepository: JSONFileWorldRepository? {
        saveDirectory.map { JSONFileWorldRepository(directory: $0) }
    }

    static func loadIslandImage() -> CGImage? {
        guard let url = islandImageURL, let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
