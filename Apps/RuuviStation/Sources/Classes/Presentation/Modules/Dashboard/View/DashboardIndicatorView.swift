import RuuviLocalization
import UIKit
import RuuviOntology

class DashboardIndicatorView: UIView {
    private lazy var indicatorValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Montserrat(.bold, size: 14)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private lazy var indicatorUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Muli(.bold, size: 12)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private lazy var indicatorTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color.withAlphaComponent(0.7)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Muli(.regular, size: 11)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private lazy var valueTextStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fill
        stack.spacing = 4
        return stack
    }()

    private lazy var contentsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 1
        return stack
    }()

    private var showTitle: Bool = false

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
        valueTextStack.addArrangedSubview(indicatorValueLabel)
        valueTextStack.addArrangedSubview(indicatorUnitLabel)

        contentsStack.addArrangedSubview(valueTextStack)
        contentsStack.addArrangedSubview(indicatorTitleLabel)

        // Add stack to view
        addSubview(contentsStack)
        contentsStack.fillSuperview()

        // Set content hugging priorities
        indicatorValueLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        indicatorUnitLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
}

extension DashboardIndicatorView {
    func setValue(
        with value: String?,
        unit: String? = nil,
        for type: MeasurementType,
        showTitle: Bool
    ) {
        self.showTitle = showTitle

        indicatorValueLabel.text = value
        indicatorUnitLabel.text = unit

        // Handle title visibility
        indicatorTitleLabel.text = type.displayName
        indicatorTitleLabel.isHidden = !showTitle

        // Hide unit label if no unit
        let isUnitEmpty = unit?.isEmpty ?? true
        indicatorUnitLabel.isHidden = isUnitEmpty || type == .aqi
    }

    func changeColor(highlight: Bool) {
        let titleColor = showTitle ? RuuviColor.dashboardIndicatorBig.color : RuuviColor.dashboardIndicator.color
        let color = highlight ? RuuviColor.orangeColor.color : titleColor
        indicatorValueLabel.textColor = color
        indicatorUnitLabel.textColor = color
    }

    func clearValues() {
        indicatorTitleLabel.text = nil
        indicatorTitleLabel.isHidden = false
        indicatorValueLabel.text = nil
        indicatorUnitLabel.text = nil
        indicatorUnitLabel.isHidden = false
        let titleColor = showTitle ? RuuviColor.dashboardIndicatorBig.color : RuuviColor.dashboardIndicator.color
        indicatorValueLabel.textColor = titleColor
        indicatorUnitLabel.textColor = titleColor
    }
}
