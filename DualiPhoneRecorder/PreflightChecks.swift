import Foundation
import UIKit
import AVFoundation

enum PreflightError: Error {
    case lowBattery
    case lowDiskSpace
    case cameraUnauthorized
    case microphoneUnauthorized
}

/// Performs storage and battery checks before recording starts.
enum PreflightChecks {
    static let minimumBatteryLevel: Float = 0.2
    static let minimumFreeSpace: Int64 = 2 * 1024 * 1024 * 1024 // 2 GB

    static func verify() throws {
        if !cameraAuthorized {
            throw PreflightError.cameraUnauthorized
        }
        if !microphoneAuthorized {
            throw PreflightError.microphoneUnauthorized
        }
        if batteryLevel < minimumBatteryLevel {
            throw PreflightError.lowBattery
        }
        if availableDiskSpace < minimumFreeSpace {
            throw PreflightError.lowDiskSpace
        }
    }

    static var batteryLevel: Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }

    static var availableDiskSpace: Int64 {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last ?? ""
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path),
           let free = attrs[.systemFreeSize] as? NSNumber {
            return free.int64Value
        }
        return 0
    }

    static var cameraAuthorized: Bool {
        authorizationStatus(for: .video)
    }

    static var microphoneAuthorized: Bool {
        authorizationStatus(for: .audio)
    }

    private static func authorizationStatus(for mediaType: AVMediaType) -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            return true
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: mediaType) { result in
                granted = result
                semaphore.signal()
            }
            semaphore.wait()
            return granted
        default:
            return false
        }
    }
}
