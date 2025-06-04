import Foundation
import AVFoundation

/// Captures video from front and back cameras simultaneously and writes to files.
final class MultiCamRecorder: NSObject {
    private let session = AVCaptureMultiCamSession()
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var backInput: AVCaptureDeviceInput?
    private var frontInput: AVCaptureDeviceInput?

    enum Mode { case dual, single }

    /// Prepare the capture session. If `mode` is `.single` it records only the back camera.
    func configure(mode: Mode = .dual) throws {
        if mode == .dual {
            guard AVCaptureMultiCamSession.isMultiCamSupported else { throw SetupError.multiCamUnavailable }
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)

        guard let back = backCamera else { throw SetupError.camerasUnavailable }

        backInput = try AVCaptureDeviceInput(device: back)
        if session.canAddInput(backInput!) { session.addInput(backInput!) }

        if mode == .dual {
            guard let front = frontCamera else { throw SetupError.camerasUnavailable }
            frontInput = try AVCaptureDeviceInput(device: front)
            if session.canAddInput(frontInput!) { session.addInput(frontInput!) }
        }

        movieFileOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieFileOutput!) { session.addOutput(movieFileOutput!) }
    }

    func start(to url: URL) {
        session.startRunning()
        movieFileOutput?.startRecording(to: url, recordingDelegate: self)
    }

    func stop() {
        movieFileOutput?.stopRecording()
        session.stopRunning()
    }
}

extension MultiCamRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {}
}

enum SetupError: Error {
    case multiCamUnavailable
    case camerasUnavailable
}
