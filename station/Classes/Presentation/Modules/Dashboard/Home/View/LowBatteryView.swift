import UIKit

class BatteryLevelView: UIView {

    private lazy var batteryLevelLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor
            .dashboardIndicatorTextColor?
            .withAlphaComponent(0.5)
        label.textAlignment = .right
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 10)
        label.text = "low_battery".localized()
        return label
    }()

    private lazy var batteryLevelIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.image = UIImage(systemName: "battery.25")
        iv.tintColor = RuuviColor.ruuviOrangeColor
        return iv
    }()

    convenience init(fontSize: CGFloat = 10) {
        self.init()
        setUpUI()
        batteryLevelLabel.font = UIFont.Muli(.regular, size: fontSize)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    required init?(coder: NSCoder) {
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
        batteryLevelIcon.heightAnchor.constraint(
            lessThanOrEqualToConstant: 22
        ).isActive = true
        batteryLevelIcon.widthAnchor.constraint(
            lessThanOrEqualToConstant: 22
        ).isActive = true

        addSubview(stack)
        stack.fillSuperview()
    }
}

extension BatteryLevelView {
    func updateTextColor(with color: UIColor?) {
        batteryLevelLabel.textColor = color
    }
}
