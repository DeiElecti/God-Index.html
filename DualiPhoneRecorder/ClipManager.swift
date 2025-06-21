import Foundation
import UIKit

/// Manages recorded movie files within the app's Documents directory.
final class ClipManager {
    private let fileManager = FileManager.default
    private var directory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// Returns URLs of all `.mov` files sorted by creation date.
    func clips() -> [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else {
            return []
        }
        return urls.filter { $0.pathExtension == "mov" }
            .sorted { (a, b) in
                let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return da < db
            }
    }

    /// Deletes the file at `url` if it exists.
    func delete(_ url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    /// Removes clips older than the given number of days.
    func purgeOlderThan(days: Int) {
        let threshold = Date().addingTimeInterval(-Double(days) * 24 * 60 * 60)
        for url in clips() {
            if let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
               date < threshold {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    /// Represents a pair of clips from the same recording session.
    struct PairedClips {
        let id: UUID
        let master: URL
        let remote: URL?
    }

    /// Returns arrays of paired clips grouped by the session identifier encoded in the filename.
    func pairedClips() -> [PairedClips] {
        var lookup: [UUID: (URL, URL?)] = [:]
        for url in clips() {
            let name = url.deletingPathExtension().lastPathComponent
            let components = name.split(separator: "_")
            guard components.count >= 2, let id = UUID(uuidString: String(components[0])) else { continue }
            let role = components[1]
            if role == "master" {
                lookup[id] = (url, lookup[id]?.1)
            } else if role == "remote" {
                let master = lookup[id]?.0
                lookup[id] = (master ?? url, url)
            }
        }
        return lookup.map { PairedClips(id: $0.key, master: $0.value.0, remote: $0.value.1) }
    }

    /// Deletes both clips associated with the given pair.
    func delete(pair: PairedClips) throws {
        try delete(pair.master)
        if let remote = pair.remote {
            try delete(remote)
        }
    }

    /// Generates and saves a JPEG thumbnail alongside the movie file.
    func generateThumbnail(for url: URL) {
        guard let image = ThumbnailGenerator.thumbnail(for: url),
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        let thumbURL = url.deletingPathExtension().appendingPathExtension("jpg")
        try? data.write(to: thumbURL)
    }

    /// Returns the stored thumbnail image for a movie file, if available.
    func thumbnail(for url: URL) -> UIImage? {
        let thumbURL = url.deletingPathExtension().appendingPathExtension("jpg")
        return UIImage(contentsOfFile: thumbURL.path)
    }

    /// Computes and stores alignment metadata for a pair of clips.
    func computeOffsetAndStore(for pair: PairedClips) {
        guard let remote = pair.remote else { return }
        if ClipMetadata.load(for: pair.master) != nil { return }
        guard let offset = ClipAligner.align(masterURL: pair.master, remoteURL: remote) else { return }
        let metadata = ClipMetadata(sessionID: pair.id, offset: offset)
        metadata.save(for: pair.master)
    }

    /// Retrieves stored metadata for a clip pair, if present.
    func metadata(for pair: PairedClips) -> ClipMetadata? {
        ClipMetadata.load(for: pair.master)
    }
}
