import UIKit

class DashboardIndicatorView: UIView {

    private lazy var indicatorValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorTextColor
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Montserrat(.bold, size: 14)
        return label
    }()

    private lazy var indicatorUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorTextColor
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 12)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setUpUI() {

        addSubview(indicatorValueLabel)
        indicatorValueLabel.anchor(top: topAnchor,
                                   leading: leadingAnchor,
                                   bottom: bottomAnchor,
                                   trailing: nil)

        addSubview(indicatorUnitLabel)
        indicatorUnitLabel.anchor(top: nil,
                                  leading: indicatorValueLabel.trailingAnchor,
                                  bottom: indicatorValueLabel.bottomAnchor,
                                  trailing: nil,
                                  padding: .init(top: 0,
                                                 left: 4,
                                                 bottom: 0,
                                                 right: 0))
        indicatorUnitLabel
            .topAnchor
            .constraint(
                lessThanOrEqualTo: indicatorValueLabel.topAnchor,
                        constant: 2
            ).isActive = true
    }
}

extension DashboardIndicatorView {
    func setValue(with value: String?, unit: String? = nil) {
        indicatorValueLabel.text = value
        indicatorUnitLabel.text = unit
    }

    func changeColor(highlight: Bool) {
        indicatorValueLabel.textColor =
            highlight ? RuuviColor.ruuviOrangeColor : RuuviColor.dashboardIndicatorTextColor
        indicatorUnitLabel.textColor =
            highlight ? RuuviColor.ruuviOrangeColor : RuuviColor.dashboardIndicatorTextColor
    }

    func clearValues() {
        indicatorValueLabel.text = nil
        indicatorUnitLabel.text = nil
        indicatorValueLabel.textColor = RuuviColor.dashboardIndicatorTextColor
        indicatorUnitLabel.textColor = RuuviColor.dashboardIndicatorTextColor
    }
}
