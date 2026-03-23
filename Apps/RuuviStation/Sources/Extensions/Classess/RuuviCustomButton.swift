import UIKit

class RuuviCustomButton: UIView {
    private enum IconVerticalAlignment {
        case center
        case top(CGFloat)
    }

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
        return iv
    }()

    private lazy var iconViewContainer = UIView(color: .clear)

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
    private var iconVerticalAlignment: IconVerticalAlignment = .center
    private var iconVerticalConstraint: NSLayoutConstraint?
    private var iconBottomConstraint: NSLayoutConstraint?

    convenience init(
        menu: UIMenu? = nil,
        icon: UIImage?,
        tintColor: UIColor = .white,
        iconSize: CGSize = .init(width: 20, height: 20),
        leadingPadding: CGFloat = 12,
        trailingPadding: CGFloat = 12,
        iconTopPadding: CGFloat? = nil
    ) {
        self.init()
        self.menu = menu
        button.menu = menu
        iconView.image = icon
        iconView.tintColor = tintColor
        self.iconSize = iconSize
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
        if let iconTopPadding {
            iconVerticalAlignment = .top(iconTopPadding)
        }
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
        addSubview(iconViewContainer)
        iconViewContainer
            .fillSuperview(
                padding: .init(
                    top: 0,
                    left: leadingPadding,
                    bottom: 0,
                    right: trailingPadding
                )
            )

        iconViewContainer.addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        iconViewContainer.heightAnchor.constraint(
            greaterThanOrEqualToConstant: iconSize.height
        ).isActive = true
        iconViewContainer.widthAnchor.constraint(
            equalToConstant: iconSize.width
        ).isActive = true

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconViewContainer.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: iconSize.width),
            iconView.heightAnchor.constraint(equalToConstant: iconSize.height),
        ])

        applyIconVerticalAlignment()

        if menu != nil {
            addSubview(button)
            button.fillSuperview()
        }
    }

    private func applyIconVerticalAlignment() {
        iconVerticalConstraint?.isActive = false
        iconBottomConstraint?.isActive = false

        switch iconVerticalAlignment {
        case .center:
            let centerYConstraint = iconView.centerYAnchor.constraint(
                equalTo: iconViewContainer.centerYAnchor
            )
            iconVerticalConstraint = centerYConstraint
            iconBottomConstraint = nil
            centerYConstraint.isActive = true
        case .top(let topPadding):
            let topConstraint = iconView.topAnchor.constraint(
                equalTo: iconViewContainer.topAnchor,
                constant: topPadding
            )
            let bottomConstraint = iconView.bottomAnchor.constraint(
                lessThanOrEqualTo: iconViewContainer.bottomAnchor
            )
            iconVerticalConstraint = topConstraint
            iconBottomConstraint = bottomConstraint
            topConstraint.isActive = true
            bottomConstraint.isActive = true
        }
    }
}

extension RuuviCustomButton {
    func setImage(image: UIImage?) {
        iconView.image = image
    }

    func updateMenu(with menu: UIMenu?) {
        button.menu = menu
    }

    func setIconTopPadding(_ topPadding: CGFloat) {
        if case .top(let currentPadding) = iconVerticalAlignment,
           abs(currentPadding - topPadding) < 0.5 {
            return
        }
        iconVerticalAlignment = .top(topPadding)
        applyIconVerticalAlignment()
    }
}
