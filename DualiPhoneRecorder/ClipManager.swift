import Foundation

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
}
