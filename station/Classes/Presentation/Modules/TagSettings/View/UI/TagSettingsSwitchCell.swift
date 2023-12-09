import UIKit

protocol TagSettingsSwitchCellDelegate: NSObjectProtocol {
    func didToggleSwitch(isOn: Bool, sender: TagSettingsSwitchCell)
}

class TagSettingsSwitchCell: UITableViewCell {
    weak var delegate: TagSettingsSwitchCellDelegate?

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.ruuviTextColor
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.bold, size: 14)
        return label
    }()

    private lazy var pairingAnimationView: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.tintColor = RuuviColor.ruuviTintColor
        return activityIndicator
    }()

    lazy var statusSwitch: RuuviUISwitch = {
        let toggle = RuuviUISwitch()
        toggle.isOn = false
        toggle.addTarget(self, action: #selector(handleStatusToggle), for: .valueChanged)
        return toggle
    }()

    lazy var seprator = UIView(color: RuuviColor.ruuviLineColor)

    override init(style: UITableViewCell.CellStyle,
                  reuseIdentifier: String?)
    {
        super.init(style: style,
                   reuseIdentifier: reuseIdentifier)
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
        titleLabel.anchor(top: safeTopAnchor,
                          leading: safeLeftAnchor,
                          bottom: safeBottomAnchor,
                          trailing: nil,
                          padding: .init(top: 12,
                                         left: 8,
                                         bottom: 12,
                                         right: 0))

        addSubview(pairingAnimationView)
        pairingAnimationView.anchor(top: nil,
                                    leading: titleLabel.trailingAnchor,
                                    bottom: nil,
                                    trailing: nil,
                                    size: .init(width: 16, height: 16))
        pairingAnimationView.centerYInSuperview()

        addSubview(statusSwitch)
        statusSwitch.anchor(top: nil,
                            leading: pairingAnimationView.trailingAnchor,
                            bottom: nil,
                            trailing: safeRightAnchor,
                            padding: .init(top: 0, left: 8,
                                           bottom: 0, right: 12),
                            size: .init(width: 51, height: 0))
        statusSwitch.centerYInSuperview()

        addSubview(seprator)
        seprator.anchor(top: nil,
                        leading: safeLeftAnchor,
                        bottom: bottomAnchor,
                        trailing: safeRightAnchor,
                        size: .init(width: 0, height: 1))
    }

    @objc private func handleStatusToggle(_ sender: RuuviUISwitch) {
        delegate?.didToggleSwitch(isOn: sender.isOn, sender: self)
    }
}

// MARK: - SETTERS

extension TagSettingsSwitchCell {
    func configure(title: String?) {
        titleLabel.text = title
    }

    func configureSwitch(value: Bool?) {
        if let value {
            statusSwitch.setOn(value, animated: false)
        } else {
            statusSwitch.setOn(false, animated: false)
        }
    }

    func disableSwitch(disable: Bool) {
        statusSwitch.isEnabled = !disable
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
