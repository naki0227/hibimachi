import Foundation
import HibimachiCore
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Writes and reads the island's daily pictures (`IslandDiary`). Files live in the app's own folder next to the
/// photos, never in the save; losing one only loses that day's picture.
@MainActor
struct IslandPictures {
    let directory: URL

    /// Today's picture, replacing an earlier one from the same day, then old pictures are removed.
    func save(_ image: CGImage?, day: LocalDay) {
        guard let image else { return }
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(IslandDiary.fileName(for: day))
        guard
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image, nil)
        _ = CGImageDestinationFinalize(destination)
        let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in IslandDiary.filesToRemove(names, today: day) {
            try? fileManager.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    func image(for day: LocalDay) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(IslandDiary.fileName(for: day)).path)
    }
}
