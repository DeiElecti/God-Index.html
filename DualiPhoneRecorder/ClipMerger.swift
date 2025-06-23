import Foundation
import AVFoundation

/// Combines master and remote clips into a single movie. The videos can be
/// arranged horizontally, vertically, or picture-in-picture.
struct ClipMerger {
    /// Layout used when combining the two videos.
    enum Layout {
        case horizontal
        case vertical
        /// Picture-in-picture layout: the remote clip is scaled down and placed
        /// in the top-right corner of the master video.
        case pip
    }

    /// Merges the two movie files and writes the result to `outputURL`.
    /// - Parameters:
    ///   - masterURL: URL of the primary clip.
    ///   - remoteURL: URL of the secondary clip.
    ///   - outputURL: Destination for the merged movie.
    ///   - completion: Called on the main queue when export finishes.
    /// - parameter offset: Optional time offset between the two clips. Positive values delay
    ///   the remote clip relative to the master. Defaults to `0`.
    static func merge(masterURL: URL,
                      remoteURL: URL,
                      outputURL: URL,
                      offset: TimeInterval = 0,
                      layout: Layout = .horizontal,
                      completion: @escaping (Result<URL, Error>) -> Void) {
        let masterAsset = AVAsset(url: masterURL)
        let remoteAsset = AVAsset(url: remoteURL)

        // Composition with two video tracks and one audio track.
        let mixComposition = AVMutableComposition()
        guard
            let masterTrack = masterAsset.tracks(withMediaType: .video).first,
            let remoteTrack = remoteAsset.tracks(withMediaType: .video).first,
            let masterAudio = masterAsset.tracks(withMediaType: .audio).first
        else {
            completion(.failure(NSError(domain: "ClipMerger", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing tracks"])));
            return
        }

        let videoTrackA = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let videoTrackB = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        let masterStart: CMTime
        let remoteStart: CMTime
        if offset >= 0 {
            masterStart = CMTime(seconds: offset, preferredTimescale: 600)
            remoteStart = .zero
        } else {
            masterStart = .zero
            remoteStart = CMTime(seconds: -offset, preferredTimescale: 600)
        }

        let duration = CMTimeMinimum(masterAsset.duration - masterStart, remoteAsset.duration - remoteStart)

        do {
            try videoTrackA?.insertTimeRange(CMTimeRange(start: masterStart, duration: duration), of: masterTrack, at: .zero)
            try videoTrackB?.insertTimeRange(CMTimeRange(start: remoteStart, duration: duration), of: remoteTrack, at: .zero)
            try audioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: masterAsset.duration), of: masterAudio, at: .zero)
        } catch {
            completion(.failure(error))
            return
        }

        // Render using a video composition.
        let videoComposition = AVMutableVideoComposition()
        switch layout {
        case .horizontal:
            videoComposition.renderSize = CGSize(width: masterTrack.naturalSize.width * 2,
                                                height: masterTrack.naturalSize.height)
        case .vertical:
            videoComposition.renderSize = CGSize(width: masterTrack.naturalSize.width,
                                                height: masterTrack.naturalSize.height * 2)
        case .pip:
            videoComposition.renderSize = masterTrack.naturalSize
        }
        videoComposition.frameDuration = masterTrack.minFrameDuration

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: masterAsset.duration)

        let masterLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrackA!)
        masterLayerInstruction.setTransform(.identity, at: .zero)

        let remoteLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrackB!)
        var transform: CGAffineTransform
        switch layout {
        case .horizontal:
            transform = CGAffineTransform(translationX: masterTrack.naturalSize.width, y: 0)
        case .vertical:
            transform = CGAffineTransform(translationX: 0, y: masterTrack.naturalSize.height)
        case .pip:
            let scale: CGFloat = 0.3
            let scaledWidth = masterTrack.naturalSize.width * scale
            let translateX = masterTrack.naturalSize.width - scaledWidth - 10
            let translateY: CGFloat = 10
            transform = CGAffineTransform(scaleX: scale, y: scale).concatenating(
                CGAffineTransform(translationX: translateX, y: translateY))
        }
        remoteLayerInstruction.setTransform(transform, at: .zero)

        instruction.layerInstructions = [masterLayerInstruction, remoteLayerInstruction]
        videoComposition.instructions = [instruction]

        // Export the composition.
        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(NSError(domain: "ClipMerger", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not create exporter"])));
            return
        }
        exporter.videoComposition = videoComposition
        exporter.outputURL = outputURL
        exporter.outputFileType = .mov
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                if exporter.status == .completed {
                    completion(.success(outputURL))
                } else {
                    completion(.failure(exporter.error ?? NSError(domain: "ClipMerger", code: -3, userInfo: [NSLocalizedDescriptionKey: "Export failed"])))
                }
            }
        }
    }
}

