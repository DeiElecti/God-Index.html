import Foundation
import UIKit

/// Monitors battery level during a recording session and executes a callback
/// when the level falls below a critical threshold.
final class BatteryMonitor {
    /// Called when battery drops below `criticalLevel`.
    var onCriticalLevel: (() -> Void)?

    /// Battery level that triggers the callback. Default is 5%.
    var criticalLevel: Float = 0.05

    private var timer: Timer?

    func startMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkLevel()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkLevel() {
        let level = UIDevice.current.batteryLevel
        if level >= 0 && level < criticalLevel {
            onCriticalLevel?()
        }
    }
}
