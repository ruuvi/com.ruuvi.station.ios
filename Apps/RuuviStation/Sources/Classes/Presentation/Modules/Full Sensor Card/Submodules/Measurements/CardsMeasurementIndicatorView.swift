import UIKit
import RuuviOntology
import RuuviLocalization
import RuuviLocal

class CardsMeasurementIndicatorView: UIView {

    // MARK: - Layout Constants
    private struct Constants {
        static let cardHeight: CGFloat = 48
        static let cornerRadius: CGFloat = cardHeight / 2
        static let iconSize: CGFloat = 24
        static let stackSpacing: CGFloat = 8
        static let valueUnitSpacing: CGFloat = 4
        static let horizontalPadding: CGFloat = 8
        static let stackTopPadding: CGFloat = 6
        static let stackBottomPadding: CGFloat = 6
        static let valueFontSize: CGFloat = 24
        static let unitFontSize: CGFloat = 14
        static let titleFontSize: CGFloat = 14
        static let borderWidth: CGFloat = 1
    }

    var onTap: (() -> Void)?

    // MARK: - Alert Properties
    private let alertBorderLayer = CAShapeLayer()

    // MARK: - Alert State Tracking
    private var currentAlertState: Bool = false
    private var currentIndicatorData: RuuviTagCardSnapshotIndicatorData?

    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.font = UIFont.Muli(.bold, size: 16)
        label.textColor = .white
        label.numberOfLines = 1
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private lazy var unitLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.Muli(.bold, size: 12)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.font = UIFont.Muli(.regular, size: 12)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupAlertBorder()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupAlertBorder()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateAlertBorderPath()
    }

    deinit {
        alertBorderLayer.removeAllAnimations()
    }

    private func setupUI() {
        backgroundColor = UIColor.white.withAlphaComponent(0.1)
        layer.cornerRadius = Constants.cornerRadius

        let valueStackView = UIStackView(
            arrangedSubviews: [valueLabel, unitLabel]
        )
        valueStackView.distribution = .fill
        valueStackView.axis = .horizontal
        valueStackView.spacing = Constants.valueUnitSpacing
        valueStackView.alignment = .lastBaseline

        let labelStackView = UIStackView(
            arrangedSubviews: [valueStackView, titleLabel]
        )
        labelStackView.distribution = .fill
        labelStackView.axis = .vertical
        labelStackView.spacing = 0

        let contentStack = UIStackView(
            arrangedSubviews: [
                iconImageView, labelStackView
            ]
        )
        iconImageView.size(
            width: Constants.iconSize,
            height: Constants.iconSize
        )
        contentStack.axis = .horizontal
        contentStack.distribution = .fill
        contentStack.alignment = .center
        contentStack.spacing = Constants.stackSpacing

        addSubview(contentStack)
        contentStack.anchor(
            top: topAnchor,
            leading: leadingAnchor,
            bottom: bottomAnchor,
            trailing: trailingAnchor,
            padding: UIEdgeInsets(
                top: Constants.stackTopPadding,
                left: Constants.horizontalPadding,
                bottom: Constants.stackBottomPadding,
                right: Constants.horizontalPadding
            )
        )
        contentStack.centerYInSuperview()

        // Set the card height
        self.constrainHeight(constant: Constants.cardHeight)

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap)
        )
        addGestureRecognizer(tapGesture)
    }

    private func setupAlertBorder() {
        alertBorderLayer.fillColor = UIColor.clear.cgColor
        alertBorderLayer.strokeColor = RuuviColor.orangeColor.color.cgColor
        alertBorderLayer.lineWidth = Constants.borderWidth
        alertBorderLayer.opacity = 0
        alertBorderLayer.isHidden = false
        layer.addSublayer(alertBorderLayer)
    }

    private func updateAlertBorderPath() {
        guard alertBorderLayer.superlayer != nil else { return }
        let borderPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: Constants.cornerRadius
        )
        alertBorderLayer.path = borderPath.cgPath
    }

    @objc private func handleTap() {
        onTap?()
    }

    // MARK: - Configuration
    func configure(with indicator: RuuviTagCardSnapshotIndicatorData) {
        let dataChanged = currentIndicatorData?.value != indicator.value ||
        currentIndicatorData?.unit != indicator.unit ||
        currentIndicatorData?.type != indicator.type

        currentIndicatorData = indicator

        if dataChanged {
            valueLabel.text = indicator.value
            titleLabel.text = indicator.type.displayName
            iconImageView.image = indicator.type.icon

            // Some units gets special treatment because they are formatted on
            // Snapshot Builder with name of the measurements for showing on Dashboard.
            // However, this screen shows the title already and
            // does not need the title as part of unit.
            if indicator.type == .pm25 {
                unitLabel.text = RuuviLocalization.unitPm25
            } else if indicator.type == .pm10 {
                unitLabel.text = RuuviLocalization.unitPm10
            } else if indicator.type == .soundInstant {
                unitLabel.text = RuuviLocalization.unitSound
            } else {
                unitLabel.text = indicator.unit
            }
        }

    }

    func updateAlertState(isHighlighted: Bool) {
        guard currentAlertState != isHighlighted else {
            return
        }

        let wasAlertFiring = currentAlertState
        currentAlertState = isHighlighted

        if currentAlertState && !wasAlertFiring {
            // Start alert animation
            startAlertBorderAnimation()
        } else if !currentAlertState && wasAlertFiring {
            // Stop alert animation
            stopAlertBorderAnimation()
        }
    }

    private func startAlertBorderAnimation() {
        // Check if animation is already running - don't interfere
        guard alertBorderLayer.animation(forKey: "pulseAnimation") == nil else {
            return
        }

        alertBorderLayer.removeAllAnimations()
        alertBorderLayer.opacity = 1.0

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.3
        animation.duration = 1.0
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        self.alertBorderLayer.add(animation, forKey: "pulseAnimation")
    }

    private func stopAlertBorderAnimation() {
        alertBorderLayer.removeAllAnimations()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self, !self.currentAlertState else { return }
            self.alertBorderLayer.opacity = 0
        }
    }

    func restartAlertAnimationIfNeeded() {
        // Only restart if we should be alerting but aren't currently animating
        if currentAlertState && alertBorderLayer.animation(forKey: "pulseAnimation") == nil {
            startAlertBorderAnimation()
        }
    }

    // MARK: - Public getter for current alert state
    var isCurrentlyAlerting: Bool {
        return currentAlertState
    }
}
