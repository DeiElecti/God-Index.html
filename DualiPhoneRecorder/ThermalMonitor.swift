import Foundation

/// Monitors the device thermal state and notifies when it becomes serious or critical.
final class ThermalMonitor {
    /// Called when the thermal state becomes serious or critical.
    var onHighThermalState: (() -> Void)?

    private var token: NSObjectProtocol?

    func startMonitoring() {
        token = NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification,
                                                       object: nil,
                                                       queue: .main) { [weak self] _ in
            self?.checkState()
        }
        checkState()
    }

    func stopMonitoring() {
        if let token = token {
            NotificationCenter.default.removeObserver(token)
        }
        token = nil
    }

    private func checkState() {
        let state = ProcessInfo.processInfo.thermalState
        if state == .serious || state == .critical {
            onHighThermalState?()
        }
    }
}
