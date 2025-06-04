import Foundation
import Kronos

/// Provides access to an NTP-synchronized clock.
final class ClockSync {
    static let shared = ClockSync()
    private var timeObserver: Clock?

    private init() {
        timeObserver = Clock.sync { _ in }
    }

    /// Returns the current synchronized time. Falls back to system clock.
    var now: TimeInterval {
        if let time = Clock.now { return time.timeIntervalSince1970 }
        return Date().timeIntervalSince1970
    }
}
