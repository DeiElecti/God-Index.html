import Foundation

/// Observes available disk space and triggers a callback when it drops below a
/// critical threshold.
final class DiskSpaceMonitor {
    /// Called when available disk space falls below `criticalBytes`.
    var onLowSpace: (() -> Void)?

    /// Minimum remaining bytes before `onLowSpace` fires. Defaults to 500 MB.
    var criticalBytes: Int64 = 500 * 1024 * 1024

    private var timer: Timer?

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkSpace()
        }
        // Check immediately as well
        checkSpace()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkSpace() {
        if Self.availableDiskSpace < criticalBytes {
            onLowSpace?()
        }
    }

    private static var availableDiskSpace: Int64 {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).last ?? ""
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: path),
           let free = attrs[.systemFreeSize] as? NSNumber {
            return free.int64Value
        }
        return 0
    }
}
