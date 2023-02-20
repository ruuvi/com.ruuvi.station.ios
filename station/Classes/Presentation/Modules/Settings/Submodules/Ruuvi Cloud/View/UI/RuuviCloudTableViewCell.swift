import UIKit

protocol RuuviCloudTableViewCellDelegate: NSObjectProtocol {
    func didToggleSwitch(isOn: Bool, sender: RuuviCloudTableViewCell)
}

class RuuviCloudTableViewCell: UITableViewCell {

    weak var delegate: RuuviCloudTableViewCellDelegate?

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.ruuviTextColor
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Muli(.bold, size: 16)
        return label
    }()

    lazy var statusSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.isOn = false
        toggle.onTintColor = .clear
        toggle.thumbTintColor = RuuviColor.ruuviTintColor
        toggle.addTarget(self,
                         action: #selector(handleStatusToggle),
                         for: .valueChanged)
        return toggle
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
        contentView.isUserInteractionEnabled = true

        backgroundColor = .clear

        addSubview(titleLabel)
        titleLabel.anchor(top: safeTopAnchor,
                          leading: safeLeftAnchor,
                          bottom: safeBottomAnchor,
                          trailing: nil,
                          padding: .init(top: 12,
                                         left: 20,
                                         bottom: 12,
                                         right: 0))

        addSubview(statusSwitch)
        statusSwitch.anchor(top: nil,
                            leading: titleLabel.trailingAnchor,
                            bottom: nil,
                            trailing: safeRightAnchor,
                            padding: .init(top: 0, left: 8, bottom: 0, right: 12))
        statusSwitch.centerYInSuperview()
    }

    @objc private func handleStatusToggle(_ sender: UISwitch) {
        delegate?.didToggleSwitch(isOn: sender.isOn, sender: self)
    }
}

// MARK: - SETTERS

extension RuuviCloudTableViewCell {

    func configure(title: String?, value: Bool?) {
        titleLabel.text = title
        if let value = value {
            statusSwitch.setOn(value, animated: false)
        } else {
            statusSwitch.setOn(false, animated: false)
        }
    }
}
