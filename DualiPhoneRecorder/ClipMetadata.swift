import Foundation

/// Stores alignment metadata for a recorded clip.
struct ClipMetadata: Codable {
    /// Session identifier shared across devices.
    let sessionID: UUID
    /// Audio offset in seconds between master and remote clip.
    let offset: TimeInterval
}

extension ClipMetadata {
    /// URL for the sidecar JSON file alongside the given movie URL.
    static func metadataURL(for movieURL: URL) -> URL {
        movieURL.deletingPathExtension().appendingPathExtension("json")
    }

    /// Saves the metadata next to the provided movie file.
    func save(for movieURL: URL) {
        let url = Self.metadataURL(for: movieURL)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: url)
        }
    }

    /// Loads metadata for the movie if available.
    static func load(for movieURL: URL) -> ClipMetadata? {
        let url = metadataURL(for: movieURL)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ClipMetadata.self, from: data)
    }
}
