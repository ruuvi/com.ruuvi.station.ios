import RuuviLocalization
import UIKit

class BatteryLevelView: UIView {
    private lazy var batteryLevelLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor
            .dashboardIndicator.color
            .withAlphaComponent(0.5)
        label.textAlignment = .right
        label.numberOfLines = 1
        label.font = UIFont.Muli(.regular, size: 10)
        label.text = RuuviLocalization.lowBattery
        return label
    }()

    private lazy var batteryLevelIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.image = UIImage(systemName: "battery.25")
        iv.tintColor = RuuviColor.orangeColor.color
        return iv
    }()

    private var iconSize: CGFloat = 20

    convenience init(fontSize: CGFloat = 10, iconSize: CGFloat = 20) {
        self.init()
        self.iconSize = iconSize
        batteryLevelLabel.font = UIFont.Muli(.regular, size: fontSize)
        setUpUI()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setUpUI() {
        clipsToBounds = true

        let stack = UIStackView(arrangedSubviews: [
            batteryLevelLabel, batteryLevelIcon
        ])
        stack.spacing = 4
        stack.axis = .horizontal
        stack.distribution = .fill
        stack.alignment = .center

        batteryLevelIcon.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
        batteryLevelIcon.widthAnchor.constraint(equalToConstant: iconSize).isActive = true

        batteryLevelLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        batteryLevelLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        batteryLevelLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)
        batteryLevelLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        batteryLevelIcon.setContentHuggingPriority(.required, for: .horizontal)
        batteryLevelIcon.setContentCompressionResistancePriority(.required, for: .horizontal)
        batteryLevelIcon.setContentHuggingPriority(.required, for: .vertical)
        batteryLevelIcon.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        addSubview(stack)
        stack.fillSuperview()
    }
}

extension BatteryLevelView {
    func updateTextColor(with color: UIColor?) {
        batteryLevelLabel.textColor = color
    }
}
