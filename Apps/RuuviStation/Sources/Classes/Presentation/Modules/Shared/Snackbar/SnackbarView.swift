import UIKit
import RuuviLocalization

final class SnackbarView: UIView {
    var onDismiss: (() -> Void)?

    init(message: String) {
        super.init(frame: .zero)
        backgroundColor = RuuviColor.snackbarBackground.color
        layer.cornerRadius = 6
        translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = message
        label.textColor = RuuviColor.ruuviGreen.color
        label.font = RuuviFonts.mulish(.bold, size: 14, for: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    override func accessibilityPerformEscape() -> Bool {
        guard let onDismiss else { return false }
        onDismiss()
        return true
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
