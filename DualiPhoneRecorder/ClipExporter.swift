import UIKit

/// Presents a share sheet to export recorded clips.
struct ClipExporter {
    /// Displays a UIActivityViewController with the provided URLs.
    static func export(_ urls: [URL], from presenter: UIViewController) {
        let activity = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        presenter.present(activity, animated: true)
    }
}
