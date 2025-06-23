import AVFoundation
import UIKit

/// Generates thumbnails for movie files.
struct ThumbnailGenerator {
    /// Returns a still image at the first frame of the movie, or nil on failure.
    static func thumbnail(for url: URL, maxSize: CGSize = CGSize(width: 300, height: 300)) -> UIImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}
