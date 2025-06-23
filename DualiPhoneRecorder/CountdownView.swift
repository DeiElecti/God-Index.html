import UIKit

/// Displays a simple countdown overlay before recording begins.
final class CountdownView: UIView {
    private let label = UILabel()
    private var timer: Timer?
    private var remaining: Int = 0
    var completion: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 72, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Starts the countdown for the given number of seconds.
    func start(seconds: Int) {
        remaining = seconds
        updateLabel()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        remaining -= 1
        if remaining <= 0 {
            timer?.invalidate()
            removeFromSuperview()
            completion?()
        } else {
            updateLabel()
        }
    }

    private func updateLabel() {
        label.text = "\(remaining)"
    }
}
