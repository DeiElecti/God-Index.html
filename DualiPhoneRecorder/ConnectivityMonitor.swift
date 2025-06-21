import Foundation
import Network

/// Monitors network connectivity and fires callbacks when the path changes.
final class ConnectivityMonitor {
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "ConnectivityMonitor")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                self?.onConnect?()
            } else {
                self?.onDisconnect?()
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
