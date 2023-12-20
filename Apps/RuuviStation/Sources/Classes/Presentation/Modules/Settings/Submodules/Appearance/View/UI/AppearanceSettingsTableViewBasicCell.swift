import RuuviLocalization
import UIKit

class AppearanceSettingsTableViewBasicCell: UITableViewCell {
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.menuTextColor.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.bold, size: 16)
        return label
    }()

    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.menuTextColor.color
        label.textAlignment = .right
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 16)
        return label
    }()

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
        accessoryType = .disclosureIndicator

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, valueLabel
        ])
        stack.spacing = 4
        stack.distribution = .fillProportionally
        stack.axis = .horizontal
        contentView.addSubview(stack)
        stack.fillSuperviewToSafeArea(
            padding: .init(top: 12, left: 20, bottom: 12, right: 8)
        )
    }
}

// MARK: - SETTERS

extension AppearanceSettingsTableViewBasicCell {
    func configure(title: String?, value: String?) {
        titleLabel.text = title
        valueLabel.text = value
    }
}
