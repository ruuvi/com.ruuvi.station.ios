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
        return iv
    }()

    private lazy var iconViewContainer: UIView = {
        let view = UIView(color: .clear)
        view.addSubview(iconView)
        iconView.centerInSuperview(size: iconSize)
        return view
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

    convenience init(
        menu: UIMenu? = nil,
        icon: UIImage?,
        tintColor: UIColor = .white,
        iconSize: CGSize = .init(width: 20, height: 20),
        leadingPadding: CGFloat = 12,
        trailingPadding: CGFloat = 12
    ) {
        self.init()
        self.menu = menu
        button.menu = menu
        iconView.image = icon
        iconView.tintColor = tintColor
        self.iconSize = iconSize
        self.leadingPadding = leadingPadding
        self.trailingPadding = trailingPadding
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

        iconViewContainer.heightAnchor.constraint(
            greaterThanOrEqualToConstant: iconSize.height
        ).isActive = true
        iconViewContainer.widthAnchor.constraint(
            equalToConstant: iconSize.width
        ).isActive = true

        if menu != nil {
            addSubview(button)
            button.fillSuperview()
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
}
