import UIKit

class AppearanceSettingsTableViewBasicCell: UITableViewCell {

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.ruuviMenuTextColor
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Muli(.bold, size: 16)
        return label
    }()

    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.ruuviMenuTextColor
        label.textAlignment = .right
        label.numberOfLines = 1
        label.font = UIFont.Muli(.regular, size: 16)
        return label
    }()

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
        accessoryType = .disclosureIndicator

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, valueLabel
        ])
        stack.spacing = 4
        stack.distribution = .fillProportionally
        stack.axis = .horizontal
        addSubview(stack)
        stack.anchor(top: safeTopAnchor,
                     leading: safeLeftAnchor,
                     bottom: safeBottomAnchor,
                     trailing: contentView.safeRightAnchor,
                     padding: .init(top: 12, left: 20, bottom: 12, right: 8))
    }
}

// MARK: - SETTERS

extension AppearanceSettingsTableViewBasicCell {
    func configure(title: String?, value: String?) {
        titleLabel.text = title
        valueLabel.text = value
    }
}
