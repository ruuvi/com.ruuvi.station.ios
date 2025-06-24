import RuuviLocalization
import UIKit

class DashboardIndicatorProminentView: UIView {

    private lazy var indicatorValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Oswald(.bold, size: 32)
        label.backgroundColor = .clear
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private lazy var indicatorSuperscriptLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Oswald(.regular, size: 12)
        label.backgroundColor = .clear
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private lazy var indicatorSubscriptLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color.withAlphaComponent(0.6)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Muli(.bold, size: 12)
        label.backgroundColor = .clear
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView()
        progressView.progressViewStyle = .bar
        progressView.trackTintColor = RuuviColor.dashboardIndicator.color.withAlphaComponent(0.3)
        progressView.layer.cornerRadius = 2.5
        progressView.clipsToBounds = true
        return progressView
    }()

    private var progressViewVisibleConstraints: [NSLayoutConstraint] = []
    private var progressViewHiddenConstraints: [NSLayoutConstraint] = []
    private var valueContainer: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable:next function_body_length
    private func setUpUI() {
        valueContainer = UIView(color: .clear)
        addSubview(valueContainer)
        valueContainer.anchor(
            top: topAnchor,
            leading: leadingAnchor,
            bottom: nil,
            trailing: trailingAnchor
        )

        // Add main value label
        valueContainer.addSubview(indicatorValueLabel)
        indicatorValueLabel.anchor(
            top: valueContainer.topAnchor,
            leading: valueContainer.leadingAnchor,
            bottom: valueContainer.bottomAnchor,
            trailing: nil
        )

        let scriptsStackView = UIStackView(
            arrangedSubviews: [indicatorSuperscriptLabel, indicatorSubscriptLabel]
        )
        scriptsStackView.axis = .vertical
        scriptsStackView.distribution = .fillEqually
        scriptsStackView.spacing = 0
        valueContainer.addSubview(scriptsStackView)
        scriptsStackView.anchor(
            top: nil,
            leading: indicatorValueLabel.trailingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 0, left: 2, bottom: 0, right: 0)
        )
        scriptsStackView.centerYAnchor.constraint(
            equalTo: indicatorValueLabel.centerYAnchor
        ).isActive = true

        // Progress view setup
        addSubview(progressView)
        progressView.anchor(
            top: nil,
            leading: leadingAnchor,
            bottom: nil,
            trailing: nil,
            size: .init(width: 120, height: 4)
        )

        progressViewVisibleConstraints = [
            progressView.topAnchor.constraint(equalTo: valueContainer.bottomAnchor, constant: 2),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
        ]

        progressViewHiddenConstraints = [
            valueContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]

        // Initially hide progress view
        NSLayoutConstraint.activate(progressViewHiddenConstraints)
        progressView.isHidden = true
    }
}

extension DashboardIndicatorProminentView {
    func setValue(
        with value: String?,
        superscriptValue: String? = nil,
        subscriptValue: String? = nil,
        showProgress: Bool = false,
        progressColor: UIColor? = .clear
    ) {
        indicatorValueLabel.text = value
        indicatorSuperscriptLabel.text = superscriptValue
        indicatorSubscriptLabel.text = subscriptValue

        // Handle progress view visibility
        progressView.isHidden = !showProgress

        if showProgress {
            NSLayoutConstraint.deactivate(progressViewHiddenConstraints)
            NSLayoutConstraint.activate(progressViewVisibleConstraints)

            if let progress = value?.intValue {
                progressView.progress = Float(progress) / 100
                progressView.progressTintColor = progressColor
            }
        } else {
            NSLayoutConstraint.deactivate(progressViewVisibleConstraints)
            NSLayoutConstraint.activate(progressViewHiddenConstraints)
        }

        setNeedsLayout()
        layoutIfNeeded()
    }

    func changeColor(highlight: Bool) {
        let mainColor = highlight ? RuuviColor.orangeColor.color : RuuviColor.dashboardIndicatorBig.color
        let subscriptColor = highlight ? RuuviColor.orangeColor.color :
                            RuuviColor.dashboardIndicator.color.withAlphaComponent(0.6)

        indicatorValueLabel.textColor = mainColor
        indicatorSuperscriptLabel.textColor = mainColor
        indicatorSubscriptLabel.textColor = subscriptColor
    }

    func clearValues() {
        indicatorValueLabel.text = nil
        indicatorSuperscriptLabel.text = nil
        indicatorSubscriptLabel.text = nil
        indicatorValueLabel.textColor = RuuviColor.dashboardIndicatorBig.color
        indicatorSuperscriptLabel.textColor = RuuviColor.dashboardIndicatorBig.color
        indicatorSubscriptLabel.textColor = RuuviColor.dashboardIndicator.color.withAlphaComponent(0.6)

        progressView.isHidden = true
        NSLayoutConstraint.deactivate(progressViewVisibleConstraints)
        NSLayoutConstraint.activate(progressViewHiddenConstraints)
    }
}
