import Foundation
import AVFoundation

/// Captures video from front and back cameras simultaneously and writes to files.
final class MultiCamRecorder: NSObject {
    private let session = AVCaptureMultiCamSession()
    private var movieFileOutput: AVCaptureMovieFileOutput?
    private var backInput: AVCaptureDeviceInput?
    private var frontInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var orientation: AVCaptureVideoOrientation = .portrait

    /// Session preset applied during configuration. Defaults to 1080p.
    var sessionPreset: AVCaptureSession.Preset = .hd1920x1080

    enum Mode { case dual, single }

    /// Prepare the capture session. If `mode` is `.single` it records only the back camera.
    func configure(mode: Mode = .dual) throws {
        if mode == .dual {
            guard AVCaptureMultiCamSession.isMultiCamSupported else { throw SetupError.multiCamUnavailable }
        }

        session.beginConfiguration()
        if session.canSetSessionPreset(sessionPreset) {
            session.sessionPreset = sessionPreset
        }
        defer { session.commitConfiguration() }

        let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        let microphone = AVCaptureDevice.default(for: .audio)

        guard let back = backCamera else { throw SetupError.camerasUnavailable }

        backInput = try AVCaptureDeviceInput(device: back)
        if session.canAddInput(backInput!) { session.addInput(backInput!) }

        if let mic = microphone {
            audioInput = try AVCaptureDeviceInput(device: mic)
            if session.canAddInput(audioInput!) { session.addInput(audioInput!) }
        }

        if mode == .dual {
            guard let front = frontCamera else { throw SetupError.camerasUnavailable }
            frontInput = try AVCaptureDeviceInput(device: front)
            if session.canAddInput(frontInput!) { session.addInput(frontInput!) }
        }

        movieFileOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieFileOutput!) { session.addOutput(movieFileOutput!) }
    }

    func start(to url: URL, orientation: AVCaptureVideoOrientation = .portrait) {
        self.orientation = orientation
        if let connection = movieFileOutput?.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }
        session.startRunning()
        movieFileOutput?.startRecording(to: url, recordingDelegate: self)
    }

    func stop() {
        movieFileOutput?.stopRecording()
        session.stopRunning()
    }

    /// Updates the orientation of the recording while the session is running.
    func update(orientation: AVCaptureVideoOrientation) {
        self.orientation = orientation
        if let connection = movieFileOutput?.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = orientation
        }
    }

    /// Lower the session preset to 720p if possible.
    func degradeToLowQuality() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else {
            throw SetupError.cannotSetLowPreset
        }
    }
}

extension MultiCamRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {}
}

enum SetupError: Error {
    case multiCamUnavailable
    case camerasUnavailable
    case cannotSetLowPreset
}
