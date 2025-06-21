# Dual-iPhone Multicam Recorder

This directory contains a starting point for the Swift project described in the PRD.
The goal is to allow two iPhones to record front and back cameras simultaneously
and keep their clips in sync.

The provided Swift files illustrate the core components:

- `PeerSessionManager.swift`: handles device discovery and communication with
  `MultipeerConnectivity`.
 - `ClockSync.swift`: demonstrates how you could obtain an accurate clock using
   the [Kronos](https://github.com/MobileNativeFoundation/Kronos) library with an
   optional fallback to [TrueTime.swift](https://github.com/instacart/TrueTime.swift).
- `MultiCamRecorder.swift`: sets up an `AVCaptureMultiCamSession` to capture
  front and back cameras plus microphone audio and record to local files.
- `RecordingCoordinator.swift`: brings the pieces together to schedule a synced
  recording start time and produce a sync cue.
- `PreflightChecks.swift`: verifies camera and microphone permission, battery level, and available storage before recording starts.
- `SyncCueGenerator.swift`: flashes the screen and plays a tone at T0 for easier alignment.
- `CountdownView.swift`: overlays a countdown before recording so users know exactly when capture will start.
- `AudioSync.swift`: simple vDSP-based audio correlation to refine clip offsets.
- `ClipManager.swift`: lists recorded movies, allows deletion, purges old clips, groups paired clips by session ID via `pairedClips()`, and can delete an entire pair via `delete(pair:)`.
- `ClipAligner.swift`: computes audio offsets between master and remote clips for post-recording alignment.
- `RecordingSession.swift`: defines a session identifier and timestamp sent between peers so each device names its files consistently.
- `BatteryMonitor.swift`: watches battery level during recording and stops the session if it falls below 5%.
 - `ThermalMonitor.swift`: observes device thermal state. When temperature is serious, the recorder drops to 720p, and if critical, the session stops.
- `DiskSpaceMonitor.swift`: monitors remaining disk space and ends the session if free space drops too low.
- `OrientationMonitor.swift`: tracks device orientation changes and updates the
  recording orientation so clips stay upright.
- `HapticFeedback.swift`: emits subtle haptic cues when recording starts and stops.
- `PeerSessionManager.swift` now reports when the connection is lost so
  `RecordingCoordinator` can stop recording if the peer disconnects.
- `ConnectivityMonitor.swift`: watches overall network reachability and stops
  recording when connectivity drops, resyncing the clock when it returns.
- `EventLogger.swift`: saves timestamped events to `events.log` for troubleshooting.

The code is written for Swift 5 and iOS 13+. It is not a full Xcode project but
can be integrated into one.

## Usage

1. Add these Swift files to your Xcode project.
2. Ensure your project includes the Kronos package for NTP time sync (or
   TrueTime.swift as a fallback).
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
If the connection to the peer drops, `RecordingCoordinator` is notified and
automatically stops the recording to avoid unsynchronised clips.
If overall network connectivity is lost, `ConnectivityMonitor` also ends the
session and re-syncs the clock once the connection returns.
All of these events are written to `events.log` by `EventLogger` for later review.

Each recording session is tagged with a UUID shared across both devices. The file names now begin with this identifier so clips from the same session are easy to match (e.g. `A1B2C_master.mov` and `A1B2C_remote.mov`).
Use `ClipManager` to list and clean up recordings after a session. The new `pairedClips()` helper groups master and remote files for easy review.
Call `delete(pair:)` to remove both clips at once when you no longer need them.
Use `ClipAligner.align` to compute the audio offset between paired clips for seamless multicam editing.

This skeleton omits UI and error handling for brevity but provides a foundation
for the networking, timing, and recording workflow.
