# Dual-iPhone Multicam Recorder

This directory contains a starting point for the Swift project described in the PRD.
The goal is to allow two iPhones to record front and back cameras simultaneously
and keep their clips in sync.

The provided Swift files illustrate the core components:

- `PeerSessionManager.swift`: handles device discovery and communication with
  `MultipeerConnectivity`.
- `ClockSync.swift`: demonstrates how you could obtain an accurate clock using
  the [Kronos](https://github.com/MobileNativeFoundation/Kronos) library.
- `MultiCamRecorder.swift`: sets up an `AVCaptureMultiCamSession` to capture
  front and back cameras plus microphone audio and record to local files.
- `RecordingCoordinator.swift`: brings the pieces together to schedule a synced
  recording start time and produce a sync cue.
- `PreflightChecks.swift`: verifies camera and microphone permission, battery level, and available storage before recording starts.
- `SyncCueGenerator.swift`: flashes the screen and plays a tone at T0 for easier alignment.
- `CountdownView.swift`: overlays a countdown before recording so users know exactly when capture will start.
- `AudioSync.swift`: simple vDSP-based audio correlation to refine clip offsets.
- `ClipManager.swift`: lists recorded movies, allows deletion, and purges old clips.
- `BatteryMonitor.swift`: watches battery level during recording and stops the session if it falls below 5%.
 - `ThermalMonitor.swift`: observes device thermal state. When temperature is serious, the recorder drops to 720p, and if critical, the session stops.
- `DiskSpaceMonitor.swift`: monitors remaining disk space and ends the session if free space drops too low.
- `OrientationMonitor.swift`: tracks device orientation changes and updates the
  recording orientation so clips stay upright.
- `HapticFeedback.swift`: emits subtle haptic cues when recording starts and stops.

The code is written for Swift 5 and iOS 13+. It is not a full Xcode project but
can be integrated into one.

## Usage

1. Add these Swift files to your Xcode project.
2. Ensure your project includes the Kronos package for NTP time sync.
3. Build and run on two iOS devices with multi-camera support (A12 or later).
4. Use one device as the host; it will advertise over `MultipeerConnectivity`.
5. When both devices are connected, press record. They will negotiate a start
   time three seconds in the future and start capturing simultaneously.

The coordinator performs basic preflight checks (permissions, battery, and disk space). At
the scheduled start, a flash and tone are emitted so the clips can be
auto-aligned later using `AudioSync.offset`. Subtle haptic feedback signals when recording begins and ends.
While recording, `BatteryMonitor` watches the remaining charge and
automatically stops the session if it drops below 5%. `ThermalMonitor`
reduces quality when the device is too warm and stops recording if it reaches a critical state.
`DiskSpaceMonitor` keeps an eye on free storage and stops before space runs out.

Use `ClipManager` to list and clean up recordings after a session.

This skeleton omits UI and error handling for brevity but provides a foundation
for the networking, timing, and recording workflow.
