import RuuviLocalization
import UIKit

class DashboardIndicatorView: UIView {
    private lazy var indicatorValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Montserrat(.bold, size: 14)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private lazy var indicatorUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Muli(.regular, size: 12)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private lazy var textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 4
        return stack
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
        // Add labels to stack
        textStack.addArrangedSubview(indicatorValueLabel)
        textStack.addArrangedSubview(indicatorUnitLabel)

        // Add stack to view
        addSubview(textStack)
        textStack.fillSuperview()

        // Set content hugging priorities
        indicatorValueLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        indicatorUnitLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
}

extension DashboardIndicatorView {
    func setValue(with value: String?, unit: String? = nil) {
        indicatorValueLabel.text = value
        indicatorUnitLabel.text = unit

        // Hide unit label if no unit
        indicatorUnitLabel.isHidden = unit?.isEmpty ?? true
    }

    func changeColor(highlight: Bool) {
        let color = highlight ? RuuviColor.orangeColor.color : RuuviColor.dashboardIndicator.color
        indicatorValueLabel.textColor = color
        indicatorUnitLabel.textColor = color
    }

    func clearValues() {
        indicatorValueLabel.text = nil
        indicatorUnitLabel.text = nil
        indicatorUnitLabel.isHidden = false
        indicatorValueLabel.textColor = RuuviColor.dashboardIndicator.color
        indicatorUnitLabel.textColor = RuuviColor.dashboardIndicator.color
    }
}
