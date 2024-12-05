import RuuviLocalization
import UIKit

class DashboardIndicatorView: UIView {
    private lazy var indicatorValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Montserrat(.bold, size: 14)
        label.sizeToFit()
        return label
    }()

    private lazy var indicatorUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 12)
        label.sizeToFit()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setUpUI() {
        let indicatorValueLabelView = UIView(color: .clear)
        indicatorValueLabelView.addSubview(indicatorValueLabel)
        indicatorValueLabel.fillSuperview()

        let indicatorUnitLabelView = UIView(color: .clear)
        indicatorUnitLabelView.addSubview(indicatorUnitLabel)
        indicatorUnitLabel.fillSuperview()

        let textStack = UIStackView(
            arrangedSubviews: [indicatorValueLabelView, indicatorUnitLabelView]
        )
        textStack.axis = .horizontal
        textStack.alignment = .center
        textStack.distribution = .fill
        textStack.spacing = 4

        indicatorValueLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        indicatorUnitLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        indicatorValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        indicatorUnitLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        addSubview(textStack)
        textStack.fillSuperview()
    }
}

extension DashboardIndicatorView {
    func setValue(with value: String?, unit: String? = nil) {
        indicatorValueLabel.text = value
        indicatorUnitLabel.text = unit

        indicatorValueLabel.sizeToFit()
        indicatorUnitLabel.sizeToFit()
        layoutIfNeeded()
    }

    func changeColor(highlight: Bool) {
        indicatorValueLabel.textColor =
        highlight ? RuuviColor.orangeColor.color : RuuviColor.dashboardIndicator.color
        indicatorUnitLabel.textColor =
        highlight ? RuuviColor.orangeColor.color : RuuviColor.dashboardIndicator.color
    }

    func clearValues() {
        indicatorValueLabel.text = nil
        indicatorUnitLabel.text = nil
        indicatorValueLabel.textColor = RuuviColor.dashboardIndicator.color
        indicatorUnitLabel.textColor = RuuviColor.dashboardIndicator.color
    }
}
