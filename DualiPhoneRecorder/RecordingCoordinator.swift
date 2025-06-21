import Foundation
import AVFoundation
import UIKit
import Network

/// Coordinates synced recording between two peers.
final class RecordingCoordinator {
    private let peer = PeerSessionManager()
    private let recorder = MultiCamRecorder()
    private let fileManager = FileManager.default
    private let clipManager = ClipManager()
    private let batteryMonitor = BatteryMonitor()
    private let thermalMonitor = ThermalMonitor()
    private let diskMonitor = DiskSpaceMonitor()
    private let orientationMonitor = OrientationMonitor()
    private let connectivityMonitor = ConnectivityMonitor()
    private let logger = EventLogger()

    private var countdownView: CountdownView?
    private var isStopping = false
    private let stopCommand = "STOP"

    private var startTime: TimeInterval?
    private var sessionID: UUID?
    private var role: Role = .host

    enum Role { case host, guest }

    init(as role: Role) {
        self.role = role
        peer.onData = { [weak self] data in
            self?.handle(data: data)
        }
        peer.onConnect = { [weak self] in
            self?.handlePeerConnect()
        }
        peer.onDisconnect = { [weak self] in
            self?.handlePeerDisconnect()
        }
        switch role {
        case .host:
            peer.startHosting()
            logger?.log("Started hosting session")
        case .guest:
            peer.joinSession()
            logger?.log("Joined session as guest")
        }
        connectivityMonitor.onConnect = {
            ClockSync.shared.resync()
            self.logger?.log("Network reachable")
        }
        connectivityMonitor.onDisconnect = { [weak self] in
            self?.handleNetworkLoss()
        }
        connectivityMonitor.start()
        logger?.log("Coordinator initialised")
    }

    /// Called by UI when user taps record.
    func initiateRecording() {
        let start = ClockSync.shared.now + 3
        startTime = start
        let id = UUID()
        sessionID = id
        let session = RecordingSession(id: id, startTime: start)
        if let data = try? JSONEncoder().encode(session) {
            try? peer.send(data: data)
        }
        logger?.log("Initiated recording for session \(id)")
        scheduleStart(at: start)
    }

    private func handle(data: Data) {
        if let session = try? JSONDecoder().decode(RecordingSession.self, from: data) {
            startTime = session.startTime
            sessionID = session.id
            scheduleStart(at: session.startTime)
        } else if let command = String(data: data, encoding: .utf8), command == stopCommand {
            stop(sendMessage: false)
        } else if data.count == MemoryLayout<UInt64>.size {
            let value = data.withUnsafeBytes { $0.load(as: UInt64.self) }
            let timestamp = TimeInterval(bitPattern: value)
            startTime = timestamp
            scheduleStart(at: timestamp)
        }
    }

    private func scheduleStart(at timestamp: TimeInterval) {
        let delay = timestamp - ClockSync.shared.now
        guard delay > 0 else { startRecording(); return }
        showCountdown(seconds: Int(ceil(delay)))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.startRecording()
        }
    }

    private func showCountdown(seconds: Int) {
        guard seconds > 0, let window = UIApplication.shared.windows.first else { return }
        let view = CountdownView(frame: window.bounds)
        countdownView = view
        window.addSubview(view)
        view.start(seconds: seconds)
    }

    private func startRecording() {
        guard let url = outputURL() else { return }
        logger?.log("Preparing to record")
        do {
            try PreflightChecks.verify()
        } catch {
            print("Preflight failed: \(error)")
            return
        }

        let mode: MultiCamRecorder.Mode = AVCaptureMultiCamSession.isMultiCamSupported ? .dual : .single
        try? recorder.configure(mode: mode)
        recorder.start(to: url, orientation: OrientationMonitor.currentOrientation)
        logger?.log("Started recording to \(url.lastPathComponent)")
        HapticFeedback.recordingStarted()
        SyncCueGenerator.trigger()
        batteryMonitor.onCriticalLevel = { [weak self] in
            self?.stop()
        }
        batteryMonitor.startMonitoring()
        thermalMonitor.onSeriousState = { [weak self] in
            try? self?.recorder.degradeToLowQuality()
        }
        thermalMonitor.onCriticalState = { [weak self] in
            self?.stop()
        }
        thermalMonitor.startMonitoring()
        diskMonitor.onLowSpace = { [weak self] in
            self?.stop()
        }
        diskMonitor.startMonitoring()

        orientationMonitor.onOrientationChange = { [weak self] orientation in
            self?.recorder.update(orientation: orientation)
            self?.logger?.log("Orientation changed to \(orientation.rawValue)")
        }
        orientationMonitor.start()
    }

    func stop(sendMessage: Bool = true) {
        guard !isStopping else { return }
        isStopping = true
        if sendMessage {
            if let data = stopCommand.data(using: .utf8) {
                try? peer.send(data: data)
            }
        }
        recorder.stop()
        HapticFeedback.recordingStopped()
        logger?.log("Recording stopped")
        clipManager.purgeOlderThan(days: 30)
        batteryMonitor.stopMonitoring()
        thermalMonitor.stopMonitoring()
        diskMonitor.stopMonitoring()
        orientationMonitor.stop()
        connectivityMonitor.stop()
    }

    /// Returns the list of recorded clip URLs.
    func availableClips() -> [URL] {
        clipManager.clips()
    }

    private func outputURL() -> URL? {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let identifier = sessionID?.uuidString ?? {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            return formatter.string(from: Date())
        }()
        let name = identifier + (role == .host ? "_master.mov" : "_remote.mov")
        return dir?.appendingPathComponent(name)
    }

    private func handlePeerConnect() {
        print("Peer connected")
        logger?.log("Peer connected")
    }

    private func handlePeerDisconnect() {
        print("Peer disconnected")
        logger?.log("Peer disconnected")
        stop()
    }

    private func handleNetworkLoss() {
        print("Network disconnected")
        logger?.log("Network disconnected")
        stop()
    }
}
