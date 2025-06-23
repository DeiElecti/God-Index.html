import Foundation
import UIKit
import AVFoundation
import AudioToolbox

/// Produces a short flash and tone to help align recordings.
enum SyncCueGenerator {
    static func trigger() {
        DispatchQueue.main.async {
            flash()
            playTone()
        }
    }

    private static func flash() {
        guard let window = UIApplication.shared.windows.first else { return }
        let view = UIView(frame: window.bounds)
        view.backgroundColor = .white
        window.addSubview(view)
        UIView.animate(withDuration: 0.08, animations: { view.alpha = 0 }) { _ in
            view.removeFromSuperview()
        }
    }

    private static func playTone() {
        AudioServicesPlaySystemSound(1103) // tri-tone
    }
}
