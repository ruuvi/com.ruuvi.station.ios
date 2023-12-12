import UIKit

protocol NotificationsSettingsSwitchCellDelegate: NSObjectProtocol {
    func didToggleSwitch(isOn: Bool, sender: NotificationsSettingsSwitchCell)
}

class NotificationsSettingsSwitchCell: UITableViewCell {
    weak var delegate: NotificationsSettingsSwitchCellDelegate?

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

    lazy var statusSwitch: RuuviUISwitch = {
        let toggle = RuuviUISwitch()
        toggle.isOn = false
        toggle.addTarget(
            self,
            action: #selector(handleStatusToggle),
            for: .valueChanged
        )
        return toggle
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
        selectionStyle = .none
        contentView.isUserInteractionEnabled = true

        backgroundColor = .clear

        let textStack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel
        ])
        textStack.spacing = 4
        textStack.distribution = .fillProportionally
        textStack.axis = .vertical
        contentView.addSubview(textStack)
        textStack.anchor(
            top: contentView.safeTopAnchor,
            leading: contentView.safeLeftAnchor,
            bottom: contentView.safeBottomAnchor,
            trailing: nil,
            padding: .init(
                top: 12,
                left: 20,
                bottom: 12,
                right: 0
            )
        )

        contentView.addSubview(statusSwitch)
        statusSwitch.anchor(
            top: nil,
            leading: textStack.trailingAnchor,
            bottom: nil,
            trailing: contentView.safeRightAnchor,
            padding: .init(top: 0, left: 8, bottom: 0, right: 12)
        )
        statusSwitch.centerYInSuperview()
    }

    @objc private func handleStatusToggle(_ sender: RuuviUISwitch) {
        delegate?.didToggleSwitch(isOn: sender.isOn, sender: self)
    }
}

// MARK: - SETTERS

extension NotificationsSettingsSwitchCell {
    func configure(title: String?, subtitle: String?, value: Bool?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        if let value {
            statusSwitch.setOn(value, animated: false)
        } else {
            statusSwitch.setOn(false, animated: false)
        }
    }
}
