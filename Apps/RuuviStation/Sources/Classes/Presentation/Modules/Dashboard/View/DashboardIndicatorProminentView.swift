import RuuviLocalization
import UIKit

class DashboardIndicatorProminentView: UIView {

    private lazy var indicatorValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.oswald(.bold, size: 34)
        label.backgroundColor = .clear
        return label
    }()

    private lazy var indicatorSuperscriptLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.oswald(.regular, size: 14)
        label.backgroundColor = .clear
        return label
    }()

    private lazy var indicatorSubscriptLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color.withAlphaComponent(0.7)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.ruuviCaption2()
        label.backgroundColor = .clear
        return label
    }()

    private var valueContainer: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUpUI() {

        valueContainer = UIView(color: .clear)
        addSubview(valueContainer)
        valueContainer.fillSuperview()

        // Add main value label
        valueContainer.addSubview(indicatorValueLabel)
        indicatorValueLabel.anchor(
            top: valueContainer.topAnchor,
            leading: valueContainer.leadingAnchor,
            bottom: valueContainer.bottomAnchor,
            trailing: valueContainer.trailingAnchor,
            // -1 to adjust padding comes from the font,
            // to make it visually center in container.
            padding: .init(top: -2, left: 0, bottom: 0, right: 0)
        )

        // Create scripts container with proper baseline alignment
        let scriptsContainer = UIView(color: .clear)

        // Position superscript aligned with top of main value
        scriptsContainer.addSubview(indicatorSuperscriptLabel)
        indicatorSuperscriptLabel.anchor(
            top: scriptsContainer.topAnchor,
            leading: scriptsContainer.leadingAnchor,
            bottom: nil,
            trailing: scriptsContainer.trailingAnchor,
            padding: .init(top: -0.5, left: 0, bottom: 0, right: 0)
        )

        // Position subscript below superscript
        scriptsContainer.addSubview(indicatorSubscriptLabel)
        indicatorSubscriptLabel.anchor(
            top: indicatorSuperscriptLabel.bottomAnchor,
            leading: scriptsContainer.leadingAnchor,
            bottom: scriptsContainer.bottomAnchor,
            trailing: scriptsContainer.trailingAnchor,
            padding: .init(top: 0.5, left: 0, bottom: 0, right: 0)
        )

        let valueStackView = UIStackView(arrangedSubviews: [
            valueContainer, scriptsContainer, UIView.flexibleSpacer()
        ])
        valueStackView.axis = .horizontal
        valueStackView.distribution = .fill
        valueStackView.spacing = 4
        addSubview(valueStackView)
        valueStackView.fillSuperview()
    }
}

extension DashboardIndicatorProminentView {
    func setValue(
        with value: String?,
        superscriptValue: String? = nil,
        subscriptValue: String? = nil
    ) {
        indicatorValueLabel.text = value
        indicatorSuperscriptLabel.text = superscriptValue
        indicatorSubscriptLabel.text = subscriptValue
    }

    func changeColor(highlight: Bool) {
        let textColor = highlight ? RuuviColor.orangeColor.color : RuuviColor.dashboardIndicatorBig.color
        indicatorValueLabel.textColor = textColor
    }

    func clearValues() {
        indicatorValueLabel.text = nil
        indicatorSuperscriptLabel.text = nil
        indicatorSubscriptLabel.text = nil
        indicatorValueLabel.textColor = RuuviColor.dashboardIndicatorBig.color
    }
}
