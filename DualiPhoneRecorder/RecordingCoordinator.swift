import Foundation
import AVFoundation
import UIKit

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

    private var countdownView: CountdownView?

    private var startTime: TimeInterval?
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
        case .host: peer.startHosting()
        case .guest: peer.joinSession()
        }
    }

    /// Called by UI when user taps record.
    func initiateRecording() {
        let start = ClockSync.shared.now + 3
        startTime = start
        let message = withUnsafeBytes(of: start.bitPattern) { Data($0) }
        try? peer.send(data: message)
        scheduleStart(at: start)
    }

    private func handle(data: Data) {
        guard data.count == MemoryLayout<UInt64>.size else { return }
        let value = data.withUnsafeBytes { $0.load(as: UInt64.self) }
        let timestamp = TimeInterval(bitPattern: value)
        startTime = timestamp
        scheduleStart(at: timestamp)
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
        do {
            try PreflightChecks.verify()
        } catch {
            print("Preflight failed: \(error)")
            return
        }

        let mode: MultiCamRecorder.Mode = AVCaptureMultiCamSession.isMultiCamSupported ? .dual : .single
        try? recorder.configure(mode: mode)
        recorder.start(to: url, orientation: OrientationMonitor.currentOrientation)
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
        }
        orientationMonitor.start()
    }

    func stop() {
        recorder.stop()
        HapticFeedback.recordingStopped()
        clipManager.purgeOlderThan(days: 30)
        batteryMonitor.stopMonitoring()
        thermalMonitor.stopMonitoring()
        diskMonitor.stopMonitoring()
        orientationMonitor.stop()
    }

    /// Returns the list of recorded clip URLs.
    func availableClips() -> [URL] {
        clipManager.clips()
    }

    private func outputURL() -> URL? {
        let dir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let name = formatter.string(from: Date()) + (role == .host ? "_master.mov" : "_remote.mov")
        return dir?.appendingPathComponent(name)
    }

    private func handlePeerConnect() {
        print("Peer connected")
    }

    private func handlePeerDisconnect() {
        print("Peer disconnected")
        stop()
    }
}
