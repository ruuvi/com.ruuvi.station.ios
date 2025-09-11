import RuuviLocalization
import UIKit

protocol RuuviCloudTableViewCellDelegate: NSObjectProtocol {
    func didToggleSwitch(isOn: Bool, sender: RuuviCloudTableViewCell)
}

class RuuviCloudTableViewCell: UITableViewCell {
    weak var delegate: RuuviCloudTableViewCellDelegate?

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.ruuviCallout()
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

        addSubview(titleLabel)
        titleLabel.anchor(
            top: safeTopAnchor,
            leading: safeLeftAnchor,
            bottom: safeBottomAnchor,
            trailing: nil,
            padding: .init(
                top: 12,
                left: 20,
                bottom: 12,
                right: 0
            )
        )

        addSubview(statusSwitch)
        statusSwitch.anchor(
            top: nil,
            leading: titleLabel.trailingAnchor,
            bottom: nil,
            trailing: safeRightAnchor,
            padding: .init(top: 0, left: 8, bottom: 0, right: 16)
        )
        statusSwitch.centerYInSuperview()
    }
}

// MARK: - RuuviSwitchViewDelegate
extension RuuviCloudTableViewCell: RuuviSwitchViewDelegate {
    func didChangeSwitchState(sender: RuuviSwitchView, didToggle isOn: Bool) {
        delegate?.didToggleSwitch(isOn: isOn, sender: self)
    }
}

// MARK: - SETTERS
extension RuuviCloudTableViewCell {
    func configure(
        title: String?,
        value: Bool?,
        hideStatusLabel: Bool
    ) {
        titleLabel.text = title
        statusSwitch.toggleState(with: value ?? false)
        statusSwitch.hideStatusLabel(hide: hideStatusLabel)
    }
}
