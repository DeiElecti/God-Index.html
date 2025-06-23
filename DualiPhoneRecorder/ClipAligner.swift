import Foundation

/// Computes the alignment offset between a master and remote clip using their audio tracks.
/// Returns the time delta in seconds that the remote clip should be shifted to match the master.
struct ClipAligner {
    /// - Parameters:
    ///   - masterURL: URL of the local/master recording.
    ///   - remoteURL: URL of the peer/remote recording.
    /// - Returns: Optional time offset in seconds. Positive if the remote clip should be delayed.
    static func align(masterURL: URL, remoteURL: URL) -> TimeInterval? {
        guard let offset = AudioSync.offset(between: masterURL, and: remoteURL) else { return nil }
        return offset
    }
}
