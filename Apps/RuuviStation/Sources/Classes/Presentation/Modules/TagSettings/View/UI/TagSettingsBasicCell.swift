import RuuviLocalization
import UIKit

enum TagSettingsBasicAccessory {
    case pencil
    case chevron
    case background
    case none
}

/// Leading title label and trailing aligned value label
/// with an optional disclosure icon.
class TagSettingsBasicCell: UITableViewCell {
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.ruuviHeadline()
        return label
    }()

    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .right
        label.numberOfLines = 1
        label.font = UIFont.ruuviBody()
        return label
    }()

    private lazy var iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private var iconHiddenWidthConstraints: [NSLayoutConstraint] = []

    private lazy var separator = UIView(color: RuuviColor.lineColor.color)

    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
        super.init(
            style: style,
            reuseIdentifier: reuseIdentifier
        )
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setUpUI() {
        backgroundColor = .clear

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, valueLabel
        ])
        stack.spacing = 4
        stack.distribution = .fill
        stack.axis = .horizontal
        addSubview(stack)
        stack.anchor(
            top: safeTopAnchor,
            leading: safeLeftAnchor,
            bottom: safeBottomAnchor,
            trailing: nil,
            padding: .init(top: 12, left: 8, bottom: 12, right: 0)
        )

        addSubview(iconView)
        iconView.anchor(
            top: nil,
            leading: stack.trailingAnchor,
            bottom: nil,
            trailing: safeRightAnchor,
            padding: .init(top: 0, left: 8, bottom: 0, right: 12),
            size: .init(width: 20, height: 20)
        )
        iconView.centerYInSuperview()
        iconHiddenWidthConstraints = [
            iconView.widthAnchor.constraint(equalToConstant: 0),
            stack.trailingAnchor.constraint(equalTo: safeRightAnchor, constant: -12),
        ]

        addSubview(separator)
        separator.anchor(
            top: nil,
            leading: safeLeftAnchor,
            bottom: bottomAnchor,
            trailing: safeRightAnchor,
            size: .init(width: 0, height: 1)
        )
    }

    func configure(title: String?, value: String?) {
        titleLabel.text = title
        valueLabel.text = value
    }

    func configure(value: String?) {
        valueLabel.text = value
    }

    func hideSeparator(hide: Bool) {
        separator.alpha = hide ? 0 : 1
    }

    func setAccessory(type: TagSettingsBasicAccessory) {
        switch type {
        case .pencil:
            iconView.image = RuuviAsset.editPen.image
            iconView.tintColor = RuuviColor.tintColor.color
            iconHiddenWidthConstraints.forEach { anchor in
                anchor.isActive = false
            }
        case .chevron:
            iconView.image = UIImage(systemName: "chevron.right")
            iconView.tintColor = .secondaryLabel
            iconHiddenWidthConstraints.forEach { anchor in
                anchor.isActive = false
            }
        case .background:
            iconView.image = UIImage(systemName: "camera.fill")
            iconView.tintColor = RuuviColor.tintColor.color
            iconHiddenWidthConstraints.forEach { anchor in
                anchor.isActive = false
            }
        case .none:
            iconView.image = nil
            iconHiddenWidthConstraints.forEach { anchor in
                anchor.isActive = true
            }
        }
    }

    func disableEditing(_ disable: Bool) {
        titleLabel.disable(disable)
        valueLabel.disable(disable)
        iconView.disable(disable)
        separator.disable(disable)
        isUserInteractionEnabled = !disable
    }
}
