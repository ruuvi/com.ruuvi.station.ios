import UIKit

class NotificationsSettingsTextCell: UITableViewCell {

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.ruuviMenuTextColor
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Muli(.bold, size: 16)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor
            .dashboardIndicatorTextColor?
            .withAlphaComponent(0.6)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 13)
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

        let leftStack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel
        ])
        leftStack.spacing = 4
        leftStack.distribution = .fillProportionally
        leftStack.axis = .vertical

        let fullStack = UIStackView(arrangedSubviews: [
            leftStack, valueLabel
        ])
        fullStack.spacing = 4
        fullStack.distribution = .fillProportionally
        fullStack.axis = .horizontal

        contentView.addSubview(fullStack)
        fullStack.fillSuperviewToSafeArea(
            padding: .init(top: 12, left: 20, bottom: 12, right: 8)
        )
    }
}

    // MARK: - SETTERS
extension NotificationsSettingsTextCell {
    func configure(title: String?, subtitle: String?, value: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        valueLabel.text = value
    }
}
