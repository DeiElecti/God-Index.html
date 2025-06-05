import Foundation
import AVFoundation
import Accelerate

/// Provides audio waveform-based alignment utilities.
enum AudioSync {
    struct AudioBuffer {
        let sampleRate: Float
        let samples: [Float]
    }

    /// Returns the time offset (in seconds) between two audio files by cross-correlating their waveforms.
    static func offset(between urlA: URL, and urlB: URL) -> TimeInterval? {
        guard let bufferA = loadSamples(from: urlA),
              let bufferB = loadSamples(from: urlB) else { return nil }

        let count = min(bufferA.samples.count, bufferB.samples.count)
        let a = Array(bufferA.samples[0..<count])
        let b = Array(bufferB.samples[0..<count])

        var result = [Float](repeating: 0, count: a.count + b.count - 1)
        vDSP_conv(a, 1, b.reversed(), 1, &result, 1, vDSP_Length(result.count), vDSP_Length(b.count))

        guard let max = result.max(), let index = result.firstIndex(of: max) else { return nil }
        let offsetSamples = index - b.count + 1
        // Use the average of both sample rates in case they differ slightly
        let sampleRate = (bufferA.sampleRate + bufferB.sampleRate) / 2
        return TimeInterval(Float(offsetSamples) / sampleRate)
    }

    private static func loadSamples(from url: URL) -> AudioBuffer? {
        let asset = AVAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else { return nil }
        do {
            let reader = try AVAssetReader(asset: asset)
            let outputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32
            ]
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
            reader.add(output)
            reader.startReading()

            var samples = [Float]()
            var sampleRate: Float = 44100
            if let formatDesc = track.formatDescriptions.first as? CMAudioFormatDescription,
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) {
                sampleRate = Float(asbd.pointee.mSampleRate)
            }

            while reader.status == .reading {
                guard let buffer = output.copyNextSampleBuffer(),
                      let block = CMSampleBufferGetDataBuffer(buffer) else { break }
                let length = CMBlockBufferGetDataLength(block)
                var data = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
                data.withUnsafeMutableBytes { ptr in
                    CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
                }
                samples.append(contentsOf: data)
            }
            return AudioBuffer(sampleRate: sampleRate, samples: samples)
        } catch {
            return nil
        }
    }
}
