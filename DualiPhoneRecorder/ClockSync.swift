import Foundation
import Kronos
#if canImport(TrueTime)
import TrueTime
#endif

/// Provides access to an NTP-synchronized clock.
final class ClockSync {
    static let shared = ClockSync()
    private var timeObserver: Clock?
#if canImport(TrueTime)
    private let trueTime = TrueTimeClient.sharedInstance
#endif

    private init() {
        timeObserver = Clock.sync { _ in }
#if canImport(TrueTime)
        trueTime.start()
#endif
    }

    /// Returns the current synchronized time. Falls back to system clock.
    var now: TimeInterval {
        if let time = Clock.now {
            return time.timeIntervalSince1970
        }
#if canImport(TrueTime)
        if let reference = try? trueTime.referenceTime() {
            return reference.now.timeIntervalSince1970
        }
#endif
        return Date().timeIntervalSince1970
    }
}
