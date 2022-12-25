import UIKit

enum TagSettingsBasicAccessory {
    case pencil
    case chevron
    case none
}

/// Leading title label and trailing aligned value label
/// with an optional disclosure icon.
class TagSettingsBasicCell: UITableViewCell {

    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.ruuviTextColor
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Muli(.bold, size: 14)
        return label
    }()

    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.ruuviTextColor
        label.textAlignment = .right
        label.numberOfLines = 1
        label.font = UIFont.Muli(.regular, size: 14)
        return label
    }()

    private lazy var iconView: UIImageView = {
        let iv = UIImageView()
        return iv
    }()

    private var iconHiddenWidthConstraints: [NSLayoutConstraint] = []

    private lazy var separator = UIView(color: RuuviColor.ruuviLineColor)

    override init(style: UITableViewCell.CellStyle,
                  reuseIdentifier: String?) {
        super.init(style: style,
                   reuseIdentifier: reuseIdentifier)
        setUpUI()
    }

    required init?(coder: NSCoder) {
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
        stack.anchor(top: safeTopAnchor,
                     leading: safeLeftAnchor,
                     bottom: safeBottomAnchor,
                     trailing: nil,
                     padding: .init(top: 12, left: 8, bottom: 12, right: 0))

        addSubview(iconView)
        iconView.anchor(top: nil,
                        leading: stack.trailingAnchor,
                        bottom: nil,
                        trailing: safeRightAnchor,
                        padding: .init(top: 0, left: 8, bottom: 0, right: 12))
        iconView.centerYInSuperview()
        iconHiddenWidthConstraints = [
            iconView.widthAnchor.constraint(equalToConstant: 0),
            stack.trailingAnchor.constraint(equalTo: safeRightAnchor, constant: -8)
        ]

        addSubview(separator)
        separator.anchor(top: nil,
                        leading: safeLeftAnchor,
                        bottom: bottomAnchor,
                        trailing: safeRightAnchor,
                        size: .init(width: 0, height: 1))
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
            iconView.image = UIImage(systemName: "pencil")
            iconView.tintColor = RuuviColor.ruuviTintColor
            iconHiddenWidthConstraints.forEach({ anchor in
                anchor.isActive = false
            })
        case .chevron:
            iconView.image = UIImage(systemName: "chevron.right")
            iconView.tintColor = .secondaryLabel
            iconHiddenWidthConstraints.forEach({ anchor in
                anchor.isActive = false
            })
        case .none:
            iconView.image = nil
            iconHiddenWidthConstraints.forEach({ anchor in
                anchor.isActive = true
            })
        }
    }
}
