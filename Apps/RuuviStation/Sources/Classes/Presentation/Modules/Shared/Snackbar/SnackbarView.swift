import UIKit

final class SnackbarView: UIView {
    var onDismiss: (() -> Void)?

    init(message: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.15, alpha: 1)
        layer.cornerRadius = 8
        translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
