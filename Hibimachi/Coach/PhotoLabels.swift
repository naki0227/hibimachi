import Foundation
import Vision

/// What is in a photo, as a few English classification labels ("desk", "food"…), from Vision on the device.
/// Used only to give the coach something to react to; never stored and never sent anywhere.
enum PhotoLabels {
    static let minimumConfidence: Float = 0.3
    static let maximumCount = 5

    static func labels(at url: URL) -> [String] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(url: url)
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return (request.results ?? [])
            .filter { $0.confidence >= minimumConfidence }
            .prefix(maximumCount)
            .map(\.identifier)
    }
}
