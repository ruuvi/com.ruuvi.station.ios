import RuuviLocalization
import UIKit

class RuuviUISwitch: UISwitch {
    private let activeThumbColor: UIColor? = RuuviColor.tintColor.color
    private let inactiveThumbColor: UIColor? = RuuviColor.switchDisabledThumbTint.color

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        updateAppearance()
    }

    override func setOn(_ on: Bool, animated: Bool) {
        super.setOn(on, animated: animated)
        updateAppearance()
    }

    @objc private func switchValueChanged() {
        updateAppearance()
    }

    private func updateAppearance() {
        if isOn {
            thumbTintColor = activeThumbColor
            onTintColor = .clear
        } else {
            thumbTintColor = inactiveThumbColor
            tintColor = .clear
        }
    }
}
