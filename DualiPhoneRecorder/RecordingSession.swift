import Foundation

/// Encapsulates a synchronized recording session.
struct RecordingSession: Codable {
    /// Unique identifier shared between peers for pairing clips.
    let id: UUID
    /// Absolute start timestamp in seconds since 1970.
    let startTime: TimeInterval
}
