import RuuviLocalization
import UIKit

protocol RuuviSwitchViewDelegate: NSObjectProtocol {
    func didChangeSwitchState(
        sender: RuuviSwitchView,
        didToggle isOn: Bool
    )
}

class RuuviSwitchView: UIView {
    // MARK: - Public
    weak var delegate: RuuviSwitchViewDelegate?

    // MARK: - UI Components
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = RuuviLocalization.off
        label.textAlignment = .right
        label.numberOfLines = 0
        label.textColor = RuuviColor.textColor.color
        label.font = UIFont.Muli(.regular, size: 14)
        return label
    }()

    private lazy var statusSwitch: RuuviUISwitch = {
        let toggle = RuuviUISwitch()
        toggle.isOn = false
        toggle.addTarget(
            self,
            action: #selector(
                handleStatusToggle
            ),
            for: .valueChanged
        )
        return toggle
    }()

    convenience init(
        delegate: RuuviSwitchViewDelegate? = nil
    ) {
        self.init()
        self.delegate = delegate
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
}

// MARK: - Public
extension RuuviSwitchView {
    func toggleState(with value: Bool?, withAnimation animated: Bool = false) {
        guard let value = value else { return }
        statusLabel.text = value ? RuuviLocalization.on : RuuviLocalization.off
        statusSwitch.setOn(value, animated: animated)
    }

    func disableEditing(
        disable: Bool
    ) {
        statusSwitch.disable(disable)
        statusLabel.disable(disable)
    }

    func isOn() -> Bool {
        return statusSwitch.isOn
    }
}

// MARK: - Private UI setup
extension RuuviSwitchView {
    private func setup() {
        backgroundColor = .clear

        addSubview(statusLabel)
        statusLabel.anchor(
            top: topAnchor,
            leading: leadingAnchor,
            bottom: bottomAnchor,
            trailing: nil
        )

        addSubview(statusSwitch)
        statusSwitch.anchor(
            top: nil,
            leading: statusLabel.trailingAnchor,
            bottom: nil,
            trailing: trailingAnchor,
            padding: .init(top: 0, left: 10, bottom: 0, right: 0)
        )
        statusSwitch.sizeToFit()
        statusSwitch.centerYInSuperview()
    }
}

// MARK: - Private action
extension RuuviSwitchView {
    @objc private func handleStatusToggle(
        _ sender: RuuviUISwitch
    ) {
        delegate?.didChangeSwitchState(
            sender: self,
            didToggle: sender.isOn
        )
        statusLabel.text = sender.isOn ? RuuviLocalization.on : RuuviLocalization.off
    }
}
