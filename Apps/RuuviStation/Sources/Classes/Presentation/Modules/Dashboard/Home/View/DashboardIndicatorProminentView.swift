import RuuviLocalization
import UIKit

class DashboardIndicatorProminentView: UIView {

    private lazy var indicatorValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Oswald(.bold, size: 30)
        return label
    }()

    private lazy var indicatorSuperscriptLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBig.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Oswald(.regular, size: 12)
        return label
    }()

    private lazy var indicatorSubscriptLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color
            .withAlphaComponent(0.6)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Muli(.bold, size: 12)
        return label
    }()

    private lazy var progressView: UIProgressView = {
        let progressView = UIProgressView()
        progressView.progressViewStyle = .bar
        progressView.trackTintColor = RuuviColor.dashboardIndicator.color
            .withAlphaComponent(0.3)
        progressView.layer.cornerRadius = 2.5
        progressView.clipsToBounds = true
        return progressView
    }()

    private var progressViewVisibleConstraints: [NSLayoutConstraint] = []
    private var progressViewHiddenConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable:next function_body_length
    fileprivate func setUpUI() {
        let valueContainer = UIView(color: .clear)
        addSubview(valueContainer)
        valueContainer.anchor(
            top: topAnchor,
            leading: leadingAnchor,
            bottom: nil,
            trailing: trailingAnchor
        )

        valueContainer.addSubview(indicatorValueLabel)
        indicatorValueLabel.anchor(
            top: valueContainer.topAnchor,
            leading: valueContainer.leadingAnchor,
            bottom: valueContainer.bottomAnchor,
            trailing: nil
        )

        let scriptsVStack = UIStackView(
            arrangedSubviews: [
                indicatorSuperscriptLabel,
                indicatorSubscriptLabel,
            ]
        )
        scriptsVStack.axis = .vertical
        scriptsVStack.alignment = .leading
        scriptsVStack.distribution = .fill
        scriptsVStack.spacing = 0
        valueContainer.addSubview(scriptsVStack)

        scriptsVStack.anchor(
            top: indicatorValueLabel.topAnchor,
            leading: indicatorValueLabel.trailingAnchor,
            bottom: indicatorValueLabel.bottomAnchor,
            trailing: nil,
            padding: .init(
                top: 6,
                left: 6,
                bottom: 6,
                right: 0
            )
        )

        scriptsVStack.trailingAnchor
            .constraint(greaterThanOrEqualTo: trailingAnchor)
            .isActive = true

        addSubview(progressView)
        progressView.anchor(
            top: nil,
            leading: leadingAnchor,
            bottom: nil,
            trailing: nil,
            size: .init(width: 120, height: 4)
        )

        progressViewVisibleConstraints = [
            progressView.topAnchor.constraint(
                equalTo: valueContainer.bottomAnchor
            ),
            progressView.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: -4
            ),
        ]

        progressViewHiddenConstraints = [
            valueContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
        ]
    }
}

extension DashboardIndicatorProminentView {
    func setValue(
        with value: String?,
        superscriptValue: String? = nil,
        subscriptValue: String? = nil,
        showProgress: Bool = false,
        progressColor: UIColor = .clear
    ) {
        indicatorValueLabel.text = value
        indicatorSuperscriptLabel.text = superscriptValue
        indicatorSubscriptLabel.text = subscriptValue

        indicatorValueLabel.sizeToFit()
        indicatorSuperscriptLabel.sizeToFit()
        indicatorSubscriptLabel.sizeToFit()

        progressView.isHidden = !showProgress
        if showProgress, let progress = value?.intValue {
            NSLayoutConstraint.deactivate(progressViewHiddenConstraints)
            NSLayoutConstraint.activate(progressViewVisibleConstraints)
            progressView.progress = Float(progress) / 100
            progressView.progressTintColor = progressColor
        } else {
            NSLayoutConstraint.deactivate(progressViewVisibleConstraints)
            NSLayoutConstraint.activate(progressViewHiddenConstraints)
        }

        layoutIfNeeded()
    }

    func changeColor(highlight: Bool) {
        indicatorValueLabel.textColor =
            highlight ? RuuviColor.orangeColor.color : RuuviColor.dashboardIndicatorBig.color
        indicatorSuperscriptLabel.textColor =
            highlight ? RuuviColor.orangeColor.color : RuuviColor.dashboardIndicatorBig.color
        indicatorSubscriptLabel.textColor =
            highlight ? RuuviColor.orangeColor.color :
                RuuviColor.dashboardIndicator.color.withAlphaComponent(0.6)
    }

    func clearValues() {
        indicatorValueLabel.text = nil
        indicatorSuperscriptLabel.text = nil
        indicatorSubscriptLabel.text = nil
        indicatorValueLabel.textColor = RuuviColor.dashboardIndicatorBig.color
        indicatorSuperscriptLabel.textColor = RuuviColor.dashboardIndicatorBig.color
        indicatorSubscriptLabel.textColor = RuuviColor.dashboardIndicator.color.withAlphaComponent(0.6)
    }
}
