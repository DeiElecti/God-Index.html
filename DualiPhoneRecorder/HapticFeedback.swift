import UIKit

/// Provides simple haptic cues at key recording events.
enum HapticFeedback {
    static func recordingStarted() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    static func recordingStopped() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
}
