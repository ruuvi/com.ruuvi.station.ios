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

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init(menu: UIMenu?,
                     titleColor: UIColor?,
                     title: String?,
                     icon: UIImage?,
                     iconTintColor: UIColor?,
                     preccedingIcon: Bool = false) {
        self.init()
        self.preccedingIcon = preccedingIcon
        self.button.menu = menu
        self.buttonTitleLabel.text = title
        self.buttonTitleLabel.textColor = titleColor
        self.buttonIconView.tintColor = iconTintColor
        self.buttonIconView.image = icon
        self.setUpUI()
    }
}

extension RuuviContextMenuButton {
    fileprivate func setUpUI() {
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
            lessThanOrEqualToConstant: 12
        ).isActive = true
        buttonIconView.widthAnchor.constraint(
            lessThanOrEqualToConstant: 12
        ).isActive = true
        stackView.axis = .horizontal
        stackView.spacing = 6
        stackView.distribution = .fill
        addSubview(stackView)
        stackView.fillSuperview()

        addSubview(button)
        button.fillSuperview()
    }
}

extension RuuviContextMenuButton {
    func updateMenu(with menu: UIMenu?) {
        self.button.menu = menu
    }

    func updateTitle(with string: String?) {
        self.buttonTitleLabel.text = string
    }
}
