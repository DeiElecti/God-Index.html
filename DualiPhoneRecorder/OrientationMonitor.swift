import Foundation
import UIKit
import AVFoundation

/// Observes device orientation changes and reports corresponding video orientation.
final class OrientationMonitor {
    var onOrientationChange: ((AVCaptureVideoOrientation) -> Void)?
    private var token: NSObjectProtocol?

    /// Begin monitoring orientation.
    func start() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        token = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification,
                                                       object: nil,
                                                       queue: .main) { [weak self] _ in
            self?.notify()
        }
        notify()
    }

    /// Stop monitoring.
    func stop() {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
        token = nil
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    /// Returns the current video orientation.
    static var currentOrientation: AVCaptureVideoOrientation {
        orientation(for: UIDevice.current.orientation) ?? .portrait
    }

    private func notify() {
        let orientation = UIDevice.current.orientation
        if let video = Self.orientation(for: orientation) {
            onOrientationChange?(video)
        }
    }

    private static func orientation(for device: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch device {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return nil
        }
    }
}
