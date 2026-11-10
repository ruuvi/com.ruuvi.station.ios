import UIKit
import RuuviLocalization

/// The timestamp is actionable only while its matching warning badge is visible.
final class MeasurementTimestampLabel: UILabel {
    var onTap: (() -> Void)?
    var isWarningVisible = false {
        didSet {
            guard isWarningVisible != oldValue else { return }
            isUserInteractionEnabled = isWarningVisible
            accessibilityTraits = isWarningVisible ? [.staticText, .button] : .staticText
            accessibilityHint = isWarningVisible ? RuuviLocalization.sensorMeasurementsOutdated : nil
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func accessibilityActivate() -> Bool {
        guard isWarningVisible, let onTap else { return false }
        onTap()
        return true
    }

    @objc private func didTap() {
        _ = accessibilityActivate()
    }
}
