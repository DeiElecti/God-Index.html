import Foundation

/// Simple event logger that writes timestamped messages to a log file in the app's Documents directory.
final class EventLogger {
    private let fileHandle: FileHandle
    private let queue = DispatchQueue(label: "EventLogger")

    init?() {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = dir.appendingPathComponent("events.log")
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: nil)
        }
        do {
            fileHandle = try FileHandle(forWritingTo: url)
            fileHandle.seekToEndOfFile()
        } catch {
            return nil
        }
    }

    /// Writes a line to the log with the current timestamp.
    func log(_ message: String) {
        queue.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            if let data = "\(timestamp) \(message)\n".data(using: .utf8) {
                try? self.fileHandle.write(contentsOf: data)
            }
        }
    }

    deinit {
        try? fileHandle.close()
    }
}
