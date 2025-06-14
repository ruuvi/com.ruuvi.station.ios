import UIKit

class RuuviCustomButton: UIView {
    var image: UIImage? {
        didSet {
            iconView.image = image
        }
    }

    private lazy var iconView: UIImageView = {
        let iv = UIImageView(
            image: nil,
            contentMode: .scaleAspectFit
        )
        iv.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        iv.setContentHuggingPriority(.defaultHigh, for: .vertical)
        iv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        iv.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return iv
    }()

    lazy var button: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.showsMenuAsPrimaryAction = true
        return button
    }()

    private var menu: UIMenu?
    private var iconSize: CGSize = .zero
    private var leadingPadding: CGFloat = 0
    private var trailingPadding: CGFloat = 0
    private var topPadding: CGFloat = 6
    private var bottomPadding: CGFloat = 6

    convenience init(
        menu: UIMenu? = nil,
        icon: UIImage?,
        tintColor: UIColor = .white,
        iconSize: CGSize = .init(width: 20, height: 20),
        leadingPadding: CGFloat = 12,
        trailingPadding: CGFloat = 12,
        topPadding: CGFloat = 6,
        bottomPadding: CGFloat = 6
    ) {
        self.init()
        self.menu = menu
        button.menu = menu
        iconView.image = icon
        iconView.tintColor = tintColor
        self.iconSize = iconSize
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        setUpUI()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RuuviCustomButton {
    private func setUpUI() {
        addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // Create size constraints with priority to avoid conflicts
        let widthConstraint = iconView.widthAnchor.constraint(equalToConstant: iconSize.width)
        let heightConstraint = iconView.heightAnchor.constraint(equalToConstant: iconSize.height)

        // Set priority to high but not required to avoid conflicts
        widthConstraint.priority = UILayoutPriority(999)
        heightConstraint.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            // Size constraints
            widthConstraint,
            heightConstraint,

            // Position constraints
            iconView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: leadingPadding),
            iconView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -trailingPadding),
            iconView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: topPadding),
            iconView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -bottomPadding),

            // Center the icon
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        if menu != nil {
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
}

extension RuuviCustomButton {
    func setImage(image: UIImage?) {
        iconView.image = image
    }

    func updateMenu(with menu: UIMenu?) {
        button.menu = menu

        // Add or remove button based on menu presence
        if menu != nil && button.superview == nil {
            addSubview(button)
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: leadingAnchor),
                button.trailingAnchor.constraint(equalTo: trailingAnchor),
                button.topAnchor.constraint(equalTo: topAnchor),
                button.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        } else if menu == nil && button.superview != nil {
            button.removeFromSuperview()
        }
    }

    func updateIconSize(_ newSize: CGSize) {
        iconSize = newSize
        setNeedsLayout()
    }
}
