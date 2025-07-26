import UIKit
import RuuviOntology
import RuuviLocalization

protocol CardsProminentIndicatorViewDelegate: AnyObject {
    func cardsProminentIndicatorViewDidTap(
        for indicator: RuuviTagCardSnapshotIndicatorData,
        sender: CardsProminentIndicatorView
    )
}

class CardsProminentIndicatorView: UIView {

    // MARK: - Height Constants (Must match SingleMeasurementPageViewController)
    private struct HeightConstants {
        static let aqiCircularViewSize: CGFloat = 150
        static let titleContainerHeight: CGFloat = 48
        static let spacingToTitle: CGFloat = 8
        static let measurementContainerHeight: CGFloat = 80
        static let borderWidth: CGFloat = 1

        static var aqiModeHeight: CGFloat {
            return aqiCircularViewSize + spacingToTitle + titleContainerHeight
        }

        static var measurementModeHeight: CGFloat {
            return measurementContainerHeight + spacingToTitle + titleContainerHeight
        }
    }

    // MARK: Configuration
    var indicatorData: RuuviTagCardSnapshotIndicatorData? {
        didSet {
            updateUI()
        }
    }

    var delegate: CardsProminentIndicatorViewDelegate?

    // MARK: - Alert Properties
    private let titleContainerAlertBorderLayer = CAShapeLayer()
    private var isAlertFiring = false

    // MARK: Private
    // MARK: AQI
    private lazy var aqiIndicatorView: AirQualityCircularView = {
        let view = AirQualityCircularView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: Measurement
    private lazy var measurementIndicatorContainer: UIView = {
        let view = UIView(color: .clear)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var measurementValueLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.Oswald(.bold, size: 42)
        label.textColor = .white
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var measurementUnitLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.font = UIFont.Oswald(.regular, size: 16)
        label.numberOfLines = 1
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: Common
    private lazy var indicatorTitleContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        view.layer.cornerRadius = 24
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var indicatorIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var indicatorTitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.Muli(.bold, size: 14)
        label.numberOfLines = 1
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: Stack Views
    private lazy var indicatorIconTitleStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [indicatorIcon, indicatorTitleLabel])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fill
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: Constraints
    private var aqiIndicatorVisibleConstraints: [NSLayoutConstraint] = []
    private var aqiIndicatorHiddenConstraints: [NSLayoutConstraint] = []
    private var viewHeightConstraint: NSLayoutConstraint!

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTitleContainerAlertBorderPath()
    }

    deinit {
        titleContainerAlertBorderLayer.removeAllAnimations()
    }

    // MARK: - Setup
    private func setupView() {
        addSubview(aqiIndicatorView)
        addSubview(measurementIndicatorContainer)
        addSubview(indicatorTitleContainer)

        // Add views to their containers
        measurementIndicatorContainer.addSubview(measurementValueLabel)
        measurementIndicatorContainer.addSubview(measurementUnitLabel)
        indicatorTitleContainer.addSubview(indicatorIconTitleStackView)

        // Configure icon size
        indicatorIcon.size(width: 24, height: 24)

        // Setup title container constraints
        indicatorIconTitleStackView.fillSuperview(
            padding: .init(top: 12, left: 24, bottom: 12, right: 24)
        )

        // Setup height constraint for the entire view
        viewHeightConstraint = heightAnchor.constraint(equalToConstant: HeightConstants.measurementModeHeight)
        viewHeightConstraint.isActive = true

        // Common constraints that don't change
        NSLayoutConstraint.activate([
            indicatorTitleContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            indicatorTitleContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicatorTitleContainer.heightAnchor.constraint(equalToConstant: HeightConstants.titleContainerHeight),
        ])

        // Setup mode-specific constraints
        setupConstraintSets()

        // Initially hide both modes
        showMeasurementMode()

        indicatorTitleContainer.isUserInteractionEnabled = true
        indicatorTitleContainer.addGestureRecognizer(
            UITapGestureRecognizer(target: self,
                                   action: #selector(handleTap))
        )

        // Setup alert border
        setupTitleContainerAlertBorder()
    }

    private func setupTitleContainerAlertBorder() {
        titleContainerAlertBorderLayer.fillColor = UIColor.clear.cgColor
        titleContainerAlertBorderLayer.strokeColor = RuuviColor.orangeColor.color.cgColor
        titleContainerAlertBorderLayer.lineWidth = HeightConstants.borderWidth
        titleContainerAlertBorderLayer.opacity = 0
        titleContainerAlertBorderLayer.isHidden = false
        indicatorTitleContainer.layer.addSublayer(titleContainerAlertBorderLayer)
    }

    private func updateTitleContainerAlertBorderPath() {
        guard titleContainerAlertBorderLayer.superlayer != nil else { return }
        let borderPath = UIBezierPath(
            roundedRect: indicatorTitleContainer.bounds,
            cornerRadius: 24
        )
        titleContainerAlertBorderLayer.path = borderPath.cgPath
    }

    private func setupConstraintSets() {
        // AQI visible constraints
        aqiIndicatorVisibleConstraints = [
            aqiIndicatorView.topAnchor.constraint(equalTo: topAnchor),
            aqiIndicatorView.bottomAnchor.constraint(
                equalTo: indicatorTitleContainer.topAnchor,
                constant: -HeightConstants.spacingToTitle
            ),
            aqiIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            aqiIndicatorView.widthAnchor.constraint(equalToConstant: HeightConstants.aqiCircularViewSize),
            aqiIndicatorView.heightAnchor.constraint(equalToConstant: HeightConstants.aqiCircularViewSize),
        ]

        // Measurement visible constraints
        aqiIndicatorHiddenConstraints = [
            // Container constraints
            measurementIndicatorContainer.topAnchor.constraint(equalTo: topAnchor),
            measurementIndicatorContainer.bottomAnchor.constraint(
                equalTo: indicatorTitleContainer.topAnchor,
                constant: -HeightConstants.spacingToTitle
            ),
            measurementIndicatorContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            measurementIndicatorContainer.heightAnchor.constraint(
                equalToConstant: HeightConstants.measurementContainerHeight
            ),

            // Value label constraints - centered in container but aligned to create superscript effect
            measurementValueLabel.centerYAnchor.constraint(equalTo: measurementIndicatorContainer.centerYAnchor),
            measurementValueLabel.leadingAnchor.constraint(equalTo: measurementIndicatorContainer.leadingAnchor),

            // Unit label constraints - positioned as superscript (top-right)
            measurementUnitLabel.topAnchor.constraint(equalTo: measurementValueLabel.topAnchor, constant: 10),
            measurementUnitLabel.leadingAnchor.constraint(equalTo: measurementValueLabel.trailingAnchor, constant: 4),
            measurementUnitLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: measurementIndicatorContainer.trailingAnchor
            ),
        ]
    }

    private func updateUI() {
        guard let indicatorData = indicatorData else {
            // Hide everything when no data
            aqiIndicatorView.isHidden = true
            measurementIndicatorContainer.isHidden = true
            indicatorTitleContainer.isHidden = true
            updateViewHeight(for: .measurement) // Default height
            updateAlertState(isHighlighted: false)
            return
        }

        // Show title container
        indicatorTitleContainer.isHidden = false

        // Update common elements
        indicatorIcon.image = indicatorData.type.icon
        indicatorTitleLabel.text = indicatorData.type.displayName

        // Update alert state
        updateAlertState(isHighlighted: indicatorData.isHighlighted)

        switch indicatorData.type {
        case .aqi:
            showAQIMode()
            updateViewHeight(for: .aqi)

            // Safe conversion with fallback
            let aqiValue = indicatorData.value.aqiIntValue ?? 0
            aqiIndicatorView.setValue(
                aqiValue,
                maxValue: 100,
                state: .excellent(Double(aqiValue))
            )

        default:
            showMeasurementMode()
            updateViewHeight(for: .measurement)

            measurementValueLabel.text = indicatorData.value
            measurementUnitLabel.text = indicatorData.unit
        }
    }

    private func updateViewHeight(for mode: ViewMode) {
        switch mode {
        case .aqi:
            viewHeightConstraint.constant = HeightConstants.aqiModeHeight
        case .measurement:
            viewHeightConstraint.constant = HeightConstants.measurementModeHeight
        }

        setNeedsLayout()
        layoutIfNeeded()
    }

    @objc private func handleTap() {
        guard let indicatorData else { return }
        delegate?.cardsProminentIndicatorViewDidTap(for: indicatorData, sender: self)
    }

    // MARK: - Mode Switching
    private func showAQIMode() {
        // Deactivate measurement constraints first
        NSLayoutConstraint.deactivate(aqiIndicatorHiddenConstraints)

        // Show AQI, hide measurement
        aqiIndicatorView.isHidden = false
        measurementIndicatorContainer.isHidden = true

        // Activate AQI constraints
        NSLayoutConstraint.activate(aqiIndicatorVisibleConstraints)
    }

    private func showMeasurementMode() {
        // Deactivate AQI constraints first
        NSLayoutConstraint.deactivate(aqiIndicatorVisibleConstraints)

        // Hide AQI, show measurement
        aqiIndicatorView.isHidden = true
        measurementIndicatorContainer.isHidden = false

        // Activate measurement constraints
        NSLayoutConstraint.activate(aqiIndicatorHiddenConstraints)
    }

    // MARK: - Alert State Management
    private func updateAlertState(isHighlighted: Bool) {
        let wasAlertFiring = isAlertFiring
        isAlertFiring = isHighlighted

        if isAlertFiring && !wasAlertFiring {
            // Start alert animation
            startTitleContainerAlertAnimation()
        } else if !isAlertFiring && wasAlertFiring {
            // Stop alert animation
            stopTitleContainerAlertAnimation()
        } else if !isAlertFiring {
            // Ensure border is hidden
            titleContainerAlertBorderLayer.opacity = 0
        }
    }

    private func startTitleContainerAlertAnimation() {
        titleContainerAlertBorderLayer.removeAllAnimations()
        titleContainerAlertBorderLayer.opacity = 1.0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isAlertFiring else { return }

            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1.0
            animation.toValue = 0.3
            animation.duration = 1.0
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            self.titleContainerAlertBorderLayer.add(animation, forKey: "pulseAnimation")
        }
    }

    private func stopTitleContainerAlertAnimation() {
        titleContainerAlertBorderLayer.removeAllAnimations()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.titleContainerAlertBorderLayer.opacity = 0
        }
    }

    func restartAlertAnimationIfNeeded() {
        if isAlertFiring {
            startTitleContainerAlertAnimation()
        }
    }

    // MARK: - Public Height Methods
    func getCurrentHeight() -> CGFloat {
        return viewHeightConstraint.constant
    }

    static func heightForAQIMode() -> CGFloat {
        return HeightConstants.aqiModeHeight
    }

    static func heightForMeasurementMode() -> CGFloat {
        return HeightConstants.measurementModeHeight
    }

    // MARK: - Static Height Access
    static func getAQIProminentHeight() -> CGFloat {
        return HeightConstants.aqiModeHeight
    }

    static func getMeasurementProminentHeight() -> CGFloat {
        return HeightConstants.measurementModeHeight
    }

    // MARK: - Helper Types
    private enum ViewMode {
        case aqi
        case measurement
    }
}

// MARK: - Air Quality Circular View (Unchanged)
class AirQualityCircularView: UIView {

    // MARK: - Layout Constants
    private struct Constants {
        static let circularViewSize: CGFloat = 150
        static let labelVerticalSpacing: CGFloat = 2
    }

    // MARK: - UI Components
    private lazy var circularProgressView: CircularProgressView = {
        let view = CircularProgressView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var currentValueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.Oswald(.bold, size: 52)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var maxValueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.Oswald(.regular, size: 16)
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.Muli(.bold, size: 24)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    var animateProgress: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        addSubview(circularProgressView)
        addSubview(currentValueLabel)
        addSubview(maxValueLabel)
        addSubview(statusLabel)
        setupConstraints()
    }

    private func setupConstraints() {
        circularProgressView.centerXInSuperview()
        circularProgressView.anchor(
            top: topAnchor,
            leading: nil,
            bottom: nil,
            trailing: nil,
            size: CGSize(width: Constants.circularViewSize, height: Constants.circularViewSize)
        )

        currentValueLabel.matchOriginTo(view: circularProgressView)

        maxValueLabel.centerXInSuperview()
        maxValueLabel.anchor(
            top: currentValueLabel.bottomAnchor,
            leading: nil,
            bottom: nil,
            trailing: nil,
            padding: UIEdgeInsets(top: Constants.labelVerticalSpacing, left: 0, bottom: 0, right: 0)
        )

        statusLabel.centerXInSuperview()
        statusLabel.anchor(
            top: circularProgressView.bottomAnchor,
            leading: nil,
            bottom: bottomAnchor,
            trailing: nil
        )
    }

    func setValue(
        _ currentValue: Int,
        maxValue: Int = 100,
        state: AirQualityState,
        animated: Bool = false
    ) {
        currentValueLabel.text = "\(currentValue)"
        maxValueLabel.text = "/\(maxValue)"
        statusLabel.text = state.title

        circularProgressView.setValue(
            currentValue,
            maxValue: maxValue,
            state: state,
            animated: animated
        )
    }
}

// MARK: - Circular Progress View (Full Implementation Restored)
class CircularProgressView: UIView {

    // MARK: - Layout Constants
    private struct Constants {
        static let radiusOffset: CGFloat = 15
        static let progressLineWidth: CGFloat = 8
        static let glowLineWidthOffset: CGFloat = 6
        static let tipCircleRadius: CGFloat = 5
        static let glowRadius: CGFloat = 8
        static let glowOpacity: Float = 0.8
        static let mainGlowSize: CGFloat = 25
        static let outerGlowSize: CGFloat = 30
        static let animationDuration: TimeInterval = 0.5

        // Arc configuration - from 135° to 45° (270° total, gap at bottom)
        static let startAngleDegrees: CGFloat = 135
        static let totalArcAngleDegrees: CGFloat = 270

        static var startAngle: CGFloat { startAngleDegrees * .pi / 180 }
        static var totalArcAngle: CGFloat { totalArcAngleDegrees * .pi / 180 }
    }

    private let progressLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    private let tipCircleLayer = CAShapeLayer()
    private let tipGlowLayer = CAShapeLayer()

    private var currentProgress: Float = 0

    var progressColor: UIColor = UIColor.green {
        didSet {
            updateProgressAppearance()
        }
    }

    var animateProgress: Bool = false

    override func layoutSubviews() {
        super.layoutSubviews()
        setupLayers()
        updateProgressAppearance()
    }

    private func setupLayers() {
        // Clear existing layers
        progressLayer.removeFromSuperlayer()
        backgroundLayer.removeFromSuperlayer()
        tipCircleLayer.removeFromSuperlayer()
        tipGlowLayer.removeFromSuperlayer()

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - Constants.radiusOffset

        // Create the arc path from 135° to 45° (270° span, gap at bottom)
        let arcPath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: Constants.startAngle,
            endAngle: Constants.startAngle + Constants.totalArcAngle,
            clockwise: true
        )

        // Background layer - full path drawn in gray
        backgroundLayer.path = arcPath.cgPath
        backgroundLayer.strokeColor = UIColor.gray.withAlphaComponent(0.3).cgColor
        backgroundLayer.lineWidth = Constants.progressLineWidth
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.lineCap = .round
        backgroundLayer.strokeEnd = 1.0
        layer.addSublayer(backgroundLayer)

        // Progress layer - main stroke on top
        progressLayer.path = arcPath.cgPath
        progressLayer.strokeColor = progressColor.cgColor
        progressLayer.lineWidth = Constants.progressLineWidth
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineCap = .round
        layer.addSublayer(progressLayer)

        // Tip glow layer (larger for more dramatic effect)
        layer.addSublayer(tipGlowLayer)

        // Tip circle layer
        tipCircleLayer.fillColor = progressColor.cgColor
        layer.addSublayer(tipCircleLayer)
    }

    private func updateProgressAppearance() {
        // Update both progress layers with the same color
        progressLayer.strokeColor = progressColor.cgColor
        // Update tip colors
        tipCircleLayer.fillColor = progressColor.cgColor
        // Update tip position
        updateTipPosition()
    }

    private func updateTipPosition() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - Constants.radiusOffset

        // Only show tip if there's progress
        guard currentProgress > 0 else {
            tipCircleLayer.path = nil
            // Clear sublayers efficiently
            tipGlowLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
            return
        }

        // Calculate the angle for the current progress
        let progressAngle = Constants.startAngle + (Constants.totalArcAngle * CGFloat(currentProgress))

        // Calculate tip position
        let tipX = center.x + radius * cos(progressAngle)
        let tipY = center.y + radius * sin(progressAngle)
        let tipCenter = CGPoint(x: tipX, y: tipY)

        // Update tip circle (main dot)
        let tipPath = UIBezierPath(ovalIn: CGRect(
            x: tipCenter.x - Constants.tipCircleRadius,
            y: tipCenter.y - Constants.tipCircleRadius,
            width: Constants.tipCircleRadius * 2,
            height: Constants.tipCircleRadius * 2
        ))
        tipCircleLayer.path = tipPath.cgPath

        // Create glow effect
        createGlowEffect(at: tipCenter)
    }

    private func createGlowEffect(at center: CGPoint) {
        // Clear existing glow layers efficiently
        tipGlowLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        // Create main glow gradient with smooth falloff
        let glowGradient = CAGradientLayer()

        // Simplified gradient colors for better performance
        glowGradient.colors = [
            progressColor.withAlphaComponent(1.0).cgColor,
            progressColor.withAlphaComponent(0.8).cgColor,
            progressColor.withAlphaComponent(0.6).cgColor,
            progressColor.withAlphaComponent(0.4).cgColor,
            progressColor.withAlphaComponent(0.2).cgColor,
            progressColor.withAlphaComponent(0.0).cgColor
        ]
        glowGradient.locations = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]

        // Position the large glow centered on tip
        glowGradient.frame = CGRect(
            x: center.x - Constants.mainGlowSize/2,
            y: center.y - Constants.mainGlowSize/2,
            width: Constants.mainGlowSize,
            height: Constants.mainGlowSize
        )
        glowGradient.type = .radial
        glowGradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowGradient.endPoint = CGPoint(x: 1.0, y: 1.0)

        // Make it circular
        let glowMask = CAShapeLayer()
        let glowPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: Constants.mainGlowSize, height: Constants.mainGlowSize))
        glowMask.path = glowPath.cgPath
        glowGradient.mask = glowMask

        tipGlowLayer.addSublayer(glowGradient)

        // Add additional outer glow for more intensity
        let outerGlowGradient = CAGradientLayer()

        outerGlowGradient.colors = [
            progressColor.withAlphaComponent(0.8).cgColor,
            progressColor.withAlphaComponent(0.6).cgColor,
            progressColor.withAlphaComponent(0.4).cgColor,
            progressColor.withAlphaComponent(0.2).cgColor,
            progressColor.withAlphaComponent(0.1).cgColor,
            progressColor.withAlphaComponent(0.0).cgColor
        ]
        outerGlowGradient.locations = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]

        outerGlowGradient.frame = CGRect(
            x: center.x - Constants.outerGlowSize/2,
            y: center.y - Constants.outerGlowSize/2,
            width: Constants.outerGlowSize,
            height: Constants.outerGlowSize
        )
        outerGlowGradient.type = .radial
        outerGlowGradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        outerGlowGradient.endPoint = CGPoint(x: 1.0, y: 1.0)

        let outerGlowMask = CAShapeLayer()
        let outerGlowPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: Constants.outerGlowSize, height: Constants.outerGlowSize))
        outerGlowMask.path = outerGlowPath.cgPath
        outerGlowGradient.mask = outerGlowMask

        tipGlowLayer.insertSublayer(outerGlowGradient, at: 0)
    }

    func setProgress(_ progress: Float, animated: Bool = false) {
        let clampedProgress = max(0, min(1, progress))
        currentProgress = clampedProgress

        if animated && animateProgress {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.strokeEnd
            animation.toValue = clampedProgress
            animation.duration = Constants.animationDuration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak self] in
                self?.updateTipPosition()
            }
            progressLayer.add(animation, forKey: "progress")
            CATransaction.commit()
        }

        // Always update strokeEnd to show progress on both layers
        progressLayer.strokeEnd = CGFloat(clampedProgress)
        updateProgressAppearance()
    }

    func setValue(
        _ value: Int,
        maxValue: Int = 100,
        state: AirQualityState,
        animated: Bool = false
    ) {
        let progress = Float(value) / Float(maxValue)
        progressColor = state.color
        setProgress(progress, animated: animated)
    }
}

// MARK: - String Extension for AQI Value Parsing
private extension String {
    var aqiIntValue: Int? {
        let components = self.components(separatedBy: "/")
        if let firstComponent = components.first {
            return Int(firstComponent.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return Int(self.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
