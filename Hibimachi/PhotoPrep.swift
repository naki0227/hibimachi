import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Prepares a picked photo for the album: decoded, rotated upright, shrunk to at most `maxPixel` on the long
/// side and re-encoded as JPEG **without metadata** (no GPS/EXIF), as docs/PRIVACY-AI.md asks.
enum PhotoPrep {
    static let maxPixel = 1280

    static func albumJPEG(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = downsample(source, maxPixel: maxPixel)
        else { return nil }
        let output = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                output as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        // Only the pixels and a quality setting go in; no properties are copied from the source.
        CGImageDestinationAddImage(
            destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    /// Small image for list rows, read straight from the file.
    static func thumbnail(at url: URL, maxPixel: Int = 240) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return downsample(source, maxPixel: maxPixel)
    }

    private static func downsample(_ source: CGImageSource, maxPixel: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
