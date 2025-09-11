import RuuviLocalization
import UIKit

protocol NotificationsSettingsSwitchCellDelegate: NSObjectProtocol {
    func didToggleSwitch(isOn: Bool, sender: NotificationsSettingsSwitchCell)
}

class NotificationsSettingsSwitchCell: UITableViewCell {
    weak var delegate: NotificationsSettingsSwitchCellDelegate?

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.menuTextColor.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.font = UIFont.ruuviHeadline()
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.textColor.color.withAlphaComponent(0.6)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.font = UIFont.ruuviFootnote()
        return label
    }()

    lazy var statusSwitch: RuuviSwitchView = {
        let toggleView = RuuviSwitchView(delegate: self)
        toggleView.toggleState(with: false)
        return toggleView
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

        // Contains the title for the item, and switch view
        let topStack = UIStackView(arrangedSubviews: [
            titleLabel, statusSwitch
        ])
        topStack.spacing = 4
        topStack.distribution = .fill
        topStack.axis = .horizontal
        statusSwitch.widthLessThanOrEqualTo(constant: 150)

        // Contains the content stack, and subtitle.
        let contentStack = UIStackView(arrangedSubviews: [
            topStack, subtitleLabel
        ])
        contentStack.spacing = 8
        contentStack.distribution = .fill
        contentStack.axis = .vertical
        contentView.addSubview(contentStack)
        contentStack.fillSuperviewToSafeArea(
            padding: .init(
            top: 12,
            left: 20,
            bottom: 12,
            right: 16)
        )
    }
}

// MARK: - RuuviSwitchViewDelegate
extension NotificationsSettingsSwitchCell: RuuviSwitchViewDelegate {
    func didChangeSwitchState(sender: RuuviSwitchView, didToggle isOn: Bool) {
        delegate?.didToggleSwitch(isOn: isOn, sender: self)
    }
}

// MARK: - SETTERS
extension NotificationsSettingsSwitchCell {
    func configure(
        title: String?,
        subtitle: String?,
        value: Bool?,
        hideStatusLabel: Bool
    ) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        statusSwitch.toggleState(with: value ?? false)
        statusSwitch.hideStatusLabel(hide: hideStatusLabel)
    }
}
