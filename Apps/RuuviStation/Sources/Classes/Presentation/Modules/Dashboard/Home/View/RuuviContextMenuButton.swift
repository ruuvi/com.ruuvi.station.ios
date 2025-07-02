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
        return label
    }()

    lazy var buttonIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
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

        let containerView = UIView(color: .clear)
        addSubview(containerView)
        containerView
            .fillSuperview(
                padding: .init(
                    top: 0,
                    left: leadingPadding,
                    bottom: 0,
                    right: trailingPadding
                )
            )

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
        buttonIconView.heightAnchor.constraint(
            lessThanOrEqualToConstant: iconSize.height
        ).isActive = true
        buttonIconView.widthAnchor.constraint(
            lessThanOrEqualToConstant: iconSize.width
        ).isActive = true
        stackView.axis = .horizontal
        stackView.spacing = interimSpacing
        stackView.distribution = .fill

        containerView.addSubview(stackView)
        stackView
            .anchor(
                top: nil,
                leading: containerView.leadingAnchor,
                bottom: nil,
                trailing: containerView.trailingAnchor
            )
        stackView.centerYInSuperview()

        addSubview(button)
        button.fillSuperview()
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
