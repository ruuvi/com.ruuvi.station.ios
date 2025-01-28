import RuuviLocalization
import UIKit

protocol TagSettingsSwitchCellDelegate: NSObjectProtocol {
    func didToggleSwitch(isOn: Bool, sender: TagSettingsSwitchCell)
}

class TagSettingsSwitchCell: UITableViewCell {
    weak var delegate: TagSettingsSwitchCellDelegate?

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.bold, size: 14)
        return label
    }()

    private lazy var pairingAnimationView: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.tintColor = RuuviColor.tintColor.color
        return activityIndicator
    }()

    lazy var statusSwitch: RuuviSwitchView = {
        let toggleView = RuuviSwitchView(delegate: self)
        toggleView.toggleState(with: false)
        return toggleView
    }()

    lazy var seprator = UIView(color: RuuviColor.lineColor.color)

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
                left: 8,
                bottom: 12,
                right: 0
            )
        )

        addSubview(pairingAnimationView)
        pairingAnimationView.anchor(
            top: nil,
            leading: titleLabel.trailingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 0, left: 6, bottom: 0, right: 0),
            size: .init(width: 16, height: 16)
        )
        pairingAnimationView.centerYInSuperview()

        addSubview(statusSwitch)
        statusSwitch.anchor(
            top: nil,
            leading: pairingAnimationView.trailingAnchor,
            bottom: nil,
            trailing: safeRightAnchor,
            padding: .init(
                top: 0,
                left: 8,
                bottom: 0,
                right: 12
            )
        )
        statusSwitch.widthLessThanOrEqualTo(constant: 350)
        statusSwitch.centerYInSuperview()

        addSubview(seprator)
        seprator.anchor(
            top: nil,
            leading: safeLeftAnchor,
            bottom: bottomAnchor,
            trailing: safeRightAnchor,
            size: .init(width: 0, height: 1)
        )
    }
}

// MARK: - RuuviSwitchViewDelegate
extension TagSettingsSwitchCell: RuuviSwitchViewDelegate {
    func didChangeSwitchState(sender: RuuviSwitchView, didToggle isOn: Bool) {
        delegate?.didToggleSwitch(isOn: isOn, sender: self)
    }
}

// MARK: - SETTERS

extension TagSettingsSwitchCell {
    func configure(title: String?) {
        titleLabel.text = title
    }

    func configureSwitch(
        value: Bool?,
        hideStatusLabel: Bool
    ) {
        statusSwitch.toggleState(with: value ?? false)
        statusSwitch.hideStatusLabel(hide: hideStatusLabel)
    }

    func disableSwitch(disable: Bool) {
        statusSwitch.disableEditing(disable: disable)
    }

    func configurePairingAnimation(start: Bool) {
        if start {
            pairingAnimationView.startAnimating()
        } else {
            pairingAnimationView.stopAnimating()
        }
    }

    func hideSeparator(hide: Bool) {
        seprator.alpha = hide ? 0 : 1
    }
}
