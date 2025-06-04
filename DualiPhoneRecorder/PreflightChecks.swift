import Foundation
import UIKit

enum PreflightError: Error {
    case lowBattery
    case lowDiskSpace
}

/// Performs storage and battery checks before recording starts.
enum PreflightChecks {
    static let minimumBatteryLevel: Float = 0.2
    static let minimumFreeSpace: Int64 = 2 * 1024 * 1024 * 1024 // 2 GB

    static func verify() throws {
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
}
