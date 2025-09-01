import RuuviLocalization
import UIKit
import RuuviOntology

class DashboardIndicatorView: UIView {
    // MARK: - UI

    private lazy var indicatorValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.mulish(.extraBold, size: 14)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private lazy var indicatorUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.mulish(.bold, size: 10)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private lazy var indicatorTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color.withAlphaComponent(0.7)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.ruuviCaption2()
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    /// Value + Unit sit here. We use stack spacing=4 to define the
    private lazy var valueRow: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [indicatorValueLabel, indicatorUnitLabel])
        stack.axis = .horizontal
        stack.alignment = .firstBaseline
        stack.distribution = .fill
        stack.spacing = 3
        return stack
    }()

    /// Top-level container that flips axis depending on dashboard type.
    private lazy var contentsStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [valueRow, indicatorTitleLabel])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 1
        return stack
    }()

    // MARK: - State

    private var dashboardType: DashboardType = .simple
    private var unitEqualsTitleHeight: NSLayoutConstraint? // only active in .simple

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    fileprivate func setUpUI() {
        addSubview(contentsStack)
        contentsStack.fillSuperview()

        // Prepare the equal-height constraint used in .simple mode.
        unitEqualsTitleHeight = indicatorUnitLabel.heightAnchor.constraint(
            equalTo: indicatorTitleLabel.heightAnchor
        )
        unitEqualsTitleHeight?.priority = .required
        unitEqualsTitleHeight?.isActive = false
    }
}

// MARK: - Public API

extension DashboardIndicatorView {
    func setValue(
        with value: String?,
        unit: String? = nil,
        for type: MeasurementType,
        dashboardType: DashboardType
    ) {
        self.dashboardType = dashboardType

        switch dashboardType {
        case .simple:
            contentsStack.axis = .horizontal
            contentsStack.alignment = .firstBaseline
            contentsStack.distribution = .fill
            contentsStack.spacing = valueRow.spacing
        case .image:
            contentsStack.axis = .vertical
            contentsStack.alignment = .leading
            contentsStack.spacing = 1
            unitEqualsTitleHeight?.isActive = false
        }

        indicatorValueLabel.text = value
        indicatorUnitLabel.text = unit

        indicatorTitleLabel.text = type.shortName

        let isUnitEmpty = unit?.isEmpty ?? true
        indicatorUnitLabel.isHidden = isUnitEmpty || MeasurementType.hideUnit(for: type)
    }

    func changeColor(highlight: Bool) {
        let color = highlight ? RuuviColor.orangeColor.color : RuuviColor.dashboardIndicatorBig.color
        indicatorValueLabel.textColor = color
    }

    func clearValues() {
        indicatorTitleLabel.text = nil
        indicatorValueLabel.text = nil
        indicatorUnitLabel.text = nil
        indicatorUnitLabel.isHidden = false
        indicatorValueLabel.textColor = RuuviColor.dashboardIndicatorBig.color
    }
}
