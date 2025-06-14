import UIKit

class RuuviContextMenuButton: UIView {
    lazy var button: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    lazy var buttonTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.Muli(.bold, size: 14)
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        return label
    }()

    lazy var buttonIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.setContentHuggingPriority(.defaultHigh, for: .vertical)
        iv.setContentCompressionResistancePriority(.defaultLow, for: .vertical) // Allow compression
        return iv
    }()

    private var preccedingIcon: Bool = false
    private var iconSize: CGSize = .init(width: 16, height: 16)
    private var interimSpacing: CGFloat = 6.0
    private var leadingPadding: CGFloat = 0.0
    private var trailingPadding: CGFloat = 0.0

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init(
        menu: UIMenu?,
        titleColor: UIColor?,
        title: String?,
        icon: UIImage?,
        iconTintColor: UIColor?,
        iconSize: CGSize = .init(width: 16, height: 16),
        interimSpacing: CGFloat = 6.0,
        leadingPadding: CGFloat = 0,
        trailingPadding: CGFloat = 0,
        preccedingIcon: Bool = false
    ) {
        self.init()
        self.preccedingIcon = preccedingIcon
        button.menu = menu
        buttonTitleLabel.text = title
        buttonTitleLabel.textColor = titleColor
        buttonIconView.tintColor = iconTintColor
        buttonIconView.image = icon
        self.iconSize = iconSize
        self.interimSpacing = interimSpacing
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        setUpUI()
    }
}

private extension RuuviContextMenuButton {
    func setUpUI() {
        var stackView = UIStackView()

        if preccedingIcon {
            buttonTitleLabel.textAlignment = .left
            stackView = UIStackView(arrangedSubviews: [
                buttonIconView, buttonTitleLabel
            ])
        } else {
            buttonTitleLabel.textAlignment = .right
            stackView = UIStackView(arrangedSubviews: [
                buttonTitleLabel, buttonIconView
            ])
        }

        // Use priority-based constraints instead of hard constraints
        let heightConstraint = buttonIconView.heightAnchor.constraint(lessThanOrEqualToConstant: iconSize.height)
        heightConstraint.priority = UILayoutPriority(999) // High priority but not required
        heightConstraint.isActive = true

        let widthConstraint = buttonIconView.widthAnchor.constraint(lessThanOrEqualToConstant: iconSize.width)
        widthConstraint.priority = UILayoutPriority(999) // High priority but not required
        widthConstraint.isActive = true

        // Add aspect ratio constraint to maintain image proportions
        if iconSize.width > 0 && iconSize.height > 0 {
            let aspectRatio = iconSize.width / iconSize.height
            buttonIconView.widthAnchor.constraint(
                equalTo: buttonIconView.heightAnchor,
                multiplier: aspectRatio
            ).isActive = true
        }

        stackView.axis = .horizontal
        stackView.spacing = interimSpacing
        stackView.distribution = .fill
        stackView.alignment = .center // Center alignment instead of fill

        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Use safe constraints for stack view
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingPadding),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -trailingPadding),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor), // Center vertically
            stackView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])

        addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

extension RuuviContextMenuButton {
    func updateMenu(with menu: UIMenu?) {
        button.menu = menu
    }

    func updateTitle(with string: String?) {
        if buttonTitleLabel.text != string {
            buttonTitleLabel.text = string
        }
    }
}
