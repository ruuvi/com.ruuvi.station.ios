// swiftlint:disable file_length

import UIKit
import RuuviOntology
import RuuviLocalization

// MARK: - Delegate Protocol
protocol CardsProminentIndicatorViewDelegate: AnyObject {
    func cardsProminentIndicatorViewDidTap(
        for indicator: RuuviTagCardSnapshotIndicatorData,
        sender: CardsProminentIndicatorView
    )
}

// MARK: - Main Prominent Indicator View
final class CardsProminentIndicatorView: UIView {

    enum ViewMode {
        case aqi
        case measurement
    }

    // MARK: - Constants
    private enum Constants {
        static let aqiCircularViewSize: CGFloat = 176
        static let titleContainerHeight: CGFloat = 48
        static let spacingToTitle: CGFloat = 30
        static let measurementContainerHeight: CGFloat = 120
        static let borderWidth: CGFloat = 1
        static let titleContainerCornerRadius: CGFloat = 24
        static let titleContainerAlpha: CGFloat = 0.15
        static let iconSize: CGFloat = 24
        static let iconTitleSpacing: CGFloat = 8
        static let containerPadding: CGFloat = 24
        static let containerVerticalPadding: CGFloat = 12
        static let measurementUnitTopOffset: CGFloat = 16
        static let measurementUnitLeadingOffset: CGFloat = 4
        static let alphaLight: CGFloat = 0.8
        static let alphaMedium: CGFloat = 0.9
        static let animationDuration: TimeInterval = 1.0
        static let animationDelay: TimeInterval = 0.05

        static var aqiModeHeight: CGFloat {
            aqiCircularViewSize + spacingToTitle + titleContainerHeight
        }

        static var measurementModeHeight: CGFloat {
            measurementContainerHeight + spacingToTitle + titleContainerHeight
        }
    }

    // MARK: - Properties
    var indicatorData: RuuviTagCardSnapshotIndicatorData? {
        didSet {
            updateUI()
        }
    }

    weak var delegate: CardsProminentIndicatorViewDelegate?

    private var currentAlertState: Bool = false
    private var currentIndicatorData: RuuviTagCardSnapshotIndicatorData?

    // MARK: - UI Components
    private lazy var aqiIndicatorView: AirQualityCircularView = {
        let view = AirQualityCircularView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var measurementIndicatorContainer: UIView = {
        let view = UIView(color: .clear)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var measurementValueLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.oswald(.bold, size: 60)
        label.textColor = .white
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var measurementUnitLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.font = UIFont.oswald(.regular, size: 18)
        label.numberOfLines = 1
        label.textColor = UIColor.white.withAlphaComponent(Constants.alphaLight)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var indicatorTitleContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(Constants.titleContainerAlpha)
        view.layer.cornerRadius = Constants.titleContainerCornerRadius
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
        label.font = UIFont.mulish(.bold, size: 14)
        label.numberOfLines = 1
        label.textColor = UIColor.white.withAlphaComponent(Constants.alphaMedium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var indicatorIconTitleStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [indicatorIcon, indicatorTitleLabel])
        stackView.axis = .horizontal
        stackView.spacing = Constants.iconTitleSpacing
        stackView.distribution = .fill
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Constraints
    private var aqiIndicatorVisibleConstraints: [NSLayoutConstraint] = []
    private var aqiIndicatorHiddenConstraints: [NSLayoutConstraint] = []
    private var viewHeightConstraint: NSLayoutConstraint!

    // MARK: - Alert Management
    private let titleContainerAlertBorderLayer = CAShapeLayer()

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

    // MARK: - Public Interface
    var isCurrentlyAlerting: Bool {
        return currentAlertState
    }

    func getCurrentHeight() -> CGFloat {
        return viewHeightConstraint.constant
    }

    static func heightForAQIMode() -> CGFloat {
        return Constants.aqiModeHeight
    }

    static func heightForMeasurementMode() -> CGFloat {
        return Constants.measurementModeHeight
    }

    static func getAQIProminentHeight() -> CGFloat {
        return Constants.aqiModeHeight
    }

    static func getMeasurementProminentHeight() -> CGFloat {
        return Constants.measurementModeHeight
    }

    func updateAlertState(isHighlighted: Bool) {
        guard currentAlertState != isHighlighted else { return }

        let wasAlertFiring = currentAlertState
        currentAlertState = isHighlighted

        if currentAlertState && !wasAlertFiring {
            startAlertBorderAnimation()
        } else if !currentAlertState && wasAlertFiring {
            stopAlertBorderAnimation()
        }
    }

    func restartAlertAnimationIfNeeded() {
        if currentAlertState &&
            titleContainerAlertBorderLayer.animation(forKey: "pulseAnimation") == nil {
            startAlertBorderAnimation()
        }
    }
}

// MARK: - Setup Methods
private extension CardsProminentIndicatorView {

    func setupView() {
        addSubviews()
        setupIconConstraints()
        setupStackViewConstraints()
        setupViewHeightConstraint()
        setupCommonConstraints()
        setupConstraintSets()
        setupInitialMode()
        setupTapGesture()
        setupTitleContainerAlertBorder()
    }

    func addSubviews() {
        addSubview(aqiIndicatorView)
        addSubview(measurementIndicatorContainer)
        addSubview(indicatorTitleContainer)

        measurementIndicatorContainer.addSubview(measurementValueLabel)
        measurementIndicatorContainer.addSubview(measurementUnitLabel)
        indicatorTitleContainer.addSubview(indicatorIconTitleStackView)
    }

    func setupIconConstraints() {
        indicatorIcon.size(width: Constants.iconSize, height: Constants.iconSize)
    }

    func setupStackViewConstraints() {
        indicatorIconTitleStackView.fillSuperview(
            padding: .init(
                top: Constants.containerVerticalPadding,
                left: Constants.containerPadding,
                bottom: Constants.containerVerticalPadding,
                right: Constants.containerPadding
            )
        )
    }

    func setupViewHeightConstraint() {
        viewHeightConstraint = heightAnchor.constraint(equalToConstant: Constants.measurementModeHeight)
        viewHeightConstraint.isActive = true
    }

    func setupCommonConstraints() {
        NSLayoutConstraint.activate([
            indicatorTitleContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            indicatorTitleContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicatorTitleContainer.heightAnchor.constraint(
                equalToConstant: Constants.titleContainerHeight
            ),
        ])
    }

    func setupConstraintSets() {
        setupAQIConstraints()
        setupMeasurementConstraints()
    }

    func setupAQIConstraints() {
        aqiIndicatorVisibleConstraints = [
            aqiIndicatorView.topAnchor.constraint(equalTo: topAnchor),
            aqiIndicatorView.bottomAnchor.constraint(
                equalTo: indicatorTitleContainer.topAnchor,
                constant: -Constants.spacingToTitle
            ),
            aqiIndicatorView.centerXAnchor.constraint(equalTo: centerXAnchor),
            aqiIndicatorView.widthAnchor.constraint(equalToConstant: Constants.aqiCircularViewSize),
            aqiIndicatorView.heightAnchor.constraint(equalToConstant: Constants.aqiCircularViewSize),
        ]
    }

    func setupMeasurementConstraints() {
        // Align measurementValueLabel with the same vertical center as
        // currentValueLabel in AQI mode The currentValueLabel is centered in the circular view.
        // Adjust the line height of the circle to match the visual center.
        let aqiValueLabelCenterY = (Constants.aqiCircularViewSize / 2) - 3

        aqiIndicatorHiddenConstraints = [
            measurementIndicatorContainer.topAnchor.constraint(equalTo: topAnchor),
            measurementIndicatorContainer.bottomAnchor.constraint(
                equalTo: indicatorTitleContainer.topAnchor,
                constant: -Constants.spacingToTitle
            ),
            measurementIndicatorContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            measurementIndicatorContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            measurementIndicatorContainer.heightAnchor.constraint(
                equalToConstant: Constants.measurementContainerHeight
            ),

            // Position measurement value at the same Y position as AQI current value
            measurementValueLabel.centerYAnchor.constraint(
                equalTo: measurementIndicatorContainer.topAnchor,
                constant: aqiValueLabelCenterY
            ),
            measurementValueLabel.centerXAnchor.constraint(equalTo: measurementIndicatorContainer.centerXAnchor),

            measurementUnitLabel.topAnchor.constraint(
                equalTo: measurementValueLabel.topAnchor,
                constant: Constants.measurementUnitTopOffset
            ),
            measurementUnitLabel.leadingAnchor.constraint(
                equalTo: measurementValueLabel.trailingAnchor,
                constant: Constants.measurementUnitLeadingOffset
            ),
            measurementUnitLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: measurementIndicatorContainer.trailingAnchor
            ),
        ]
    }

    func setupInitialMode() {
        showMeasurementMode()
    }

    func setupTapGesture() {
        indicatorTitleContainer.isUserInteractionEnabled = true
        indicatorTitleContainer.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleTap))
        )
    }

    func setupTitleContainerAlertBorder() {
        titleContainerAlertBorderLayer.fillColor = UIColor.clear.cgColor
        titleContainerAlertBorderLayer.strokeColor = RuuviColor.orangeColor.color.cgColor
        titleContainerAlertBorderLayer.lineWidth = Constants.borderWidth
        titleContainerAlertBorderLayer.opacity = 0
        titleContainerAlertBorderLayer.isHidden = false
        indicatorTitleContainer.layer.addSublayer(titleContainerAlertBorderLayer)
    }
}

// MARK: - UI Update Methods
private extension CardsProminentIndicatorView {

    func updateUI() {
        guard let indicatorData = indicatorData else {
            handleNoData()
            return
        }

        showTitleContainer()
        updateCommonElements(with: indicatorData)

        switch indicatorData.type {
        case .aqi:
            handleAQIMode(with: indicatorData)
        default:
            handleMeasurementMode(with: indicatorData)
        }
    }

    func handleNoData() {
        aqiIndicatorView.isHidden = true
        measurementIndicatorContainer.isHidden = true
        indicatorTitleContainer.isHidden = true
        updateViewHeight(for: .measurement)
        updateAlertState(isHighlighted: false)
    }

    func showTitleContainer() {
        indicatorTitleContainer.isHidden = false
    }

    func updateCommonElements(with indicatorData: RuuviTagCardSnapshotIndicatorData) {
        indicatorIcon.image = indicatorData.type.icon
        indicatorTitleLabel.text = indicatorData.type.shortName
    }

    func handleAQIMode(with indicatorData: RuuviTagCardSnapshotIndicatorData) {
        showAQIMode()
        updateViewHeight(for: .aqi)

        if let aqiValue = indicatorData.value.aqiIntValue,
           let aqiState = indicatorData.aqiState {
            aqiIndicatorView.setValue(aqiValue, maxValue: 100, state: aqiState)
        }
    }

    func handleMeasurementMode(with indicatorData: RuuviTagCardSnapshotIndicatorData) {
        showMeasurementMode()
        updateViewHeight(for: .measurement)

        measurementValueLabel.text = indicatorData.value
        measurementUnitLabel.text = indicatorData.unit
    }

    func updateViewHeight(for mode: ViewMode) {
        switch mode {
        case .aqi:
            viewHeightConstraint.constant = Constants.aqiModeHeight
        case .measurement:
            viewHeightConstraint.constant = Constants.measurementModeHeight
        }

        setNeedsLayout()
        layoutIfNeeded()
    }
}

// MARK: - Mode Switching
private extension CardsProminentIndicatorView {

    func showAQIMode() {
        NSLayoutConstraint.deactivate(aqiIndicatorHiddenConstraints)

        aqiIndicatorView.isHidden = false
        measurementIndicatorContainer.isHidden = true

        NSLayoutConstraint.activate(aqiIndicatorVisibleConstraints)
    }

    func showMeasurementMode() {
        NSLayoutConstraint.deactivate(aqiIndicatorVisibleConstraints)

        aqiIndicatorView.isHidden = true
        measurementIndicatorContainer.isHidden = false

        NSLayoutConstraint.activate(aqiIndicatorHiddenConstraints)
    }
}

// MARK: - Alert Management
private extension CardsProminentIndicatorView {

    func updateTitleContainerAlertBorderPath() {
        guard titleContainerAlertBorderLayer.superlayer != nil else { return }

        let borderPath = UIBezierPath(
            roundedRect: indicatorTitleContainer.bounds,
            cornerRadius: Constants.titleContainerCornerRadius
        )
        titleContainerAlertBorderLayer.path = borderPath.cgPath
    }

    func startAlertBorderAnimation() {
        guard titleContainerAlertBorderLayer.animation(forKey: "pulseAnimation") == nil else { return }

        titleContainerAlertBorderLayer.removeAllAnimations()
        titleContainerAlertBorderLayer.opacity = 1.0

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.3
        animation.duration = Constants.animationDuration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        titleContainerAlertBorderLayer.add(animation, forKey: "pulseAnimation")
    }

    func stopAlertBorderAnimation() {
        titleContainerAlertBorderLayer.removeAllAnimations()

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.animationDelay) { [weak self] in
            guard let self = self, !self.currentAlertState else { return }
            self.titleContainerAlertBorderLayer.opacity = 0
        }
    }
}

// MARK: - Actions
private extension CardsProminentIndicatorView {

    @objc func handleTap() {
        guard let indicatorData else { return }
        delegate?.cardsProminentIndicatorViewDidTap(for: indicatorData, sender: self)
    }
}

// MARK: - Air Quality Circular View
final class AirQualityCircularView: UIView {

    // MARK: - Constants
    private enum Constants {
        static let circularViewSize: CGFloat = 150
        static let labelVerticalSpacing: CGFloat = 0
        static let statusLabelBottomMargin: CGFloat = 0
        static let currentValueFontSize: CGFloat = 60
        static let maxValueFontSize: CGFloat = 18
        static let statusLabelFontSize: CGFloat = 20
        static let alphaLight: CGFloat = 1.0
    }

    // MARK: - UI Components
    private lazy var circularProgressView: CircularProgressView = {
        let view = CircularProgressView()
        view.overrideUserInterfaceStyle = .dark
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var currentValueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.oswald(.bold, size: Constants.currentValueFontSize)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var maxValueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.oswald(.regular, size: Constants.maxValueFontSize)
        label.textColor = UIColor.white.withAlphaComponent(Constants.alphaLight)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.mulish(.extraBold, size: Constants.statusLabelFontSize)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    var animateProgress: Bool = false

    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Public Interface
    func setValue(
        _ currentValue: Int,
        maxValue: Int = 100,
        state: AirQualityState,
        animated: Bool = false
    ) {
        currentValueLabel.text = "\(currentValue)"
        maxValueLabel.text = "/\(maxValue)"
        statusLabel.text = state.title

        circularProgressView
            .setValue(
                currentValue,
                maxValue: maxValue,
                state: state,
                animated: animated
            )
    }
}

// MARK: - AQI Setup Methods
private extension AirQualityCircularView {

    func setupUI() {
        addSubviews()
        setupConstraints()
    }

    func addSubviews() {
        addSubview(circularProgressView)
        addSubview(currentValueLabel)
        addSubview(maxValueLabel)
        addSubview(statusLabel)
    }

    func setupConstraints() {
        setupCircularProgressConstraints()
        setupCurrentValueConstraints()
        setupMaxValueConstraints()
        setupStatusLabelConstraints()
    }

    func setupCircularProgressConstraints() {
        // Center the circular progress view both horizontally and vertically
        NSLayoutConstraint.activate([
            circularProgressView.centerXAnchor.constraint(equalTo: centerXAnchor),
            circularProgressView.centerYAnchor.constraint(equalTo: centerYAnchor),
            circularProgressView.widthAnchor.constraint(
                equalToConstant: Constants.circularViewSize
            ),
            circularProgressView.heightAnchor.constraint(
                equalToConstant: Constants.circularViewSize
            ),
        ])
    }

    func setupCurrentValueConstraints() {
        // Center the current value label in the circular progress view
        NSLayoutConstraint.activate(
            [
                currentValueLabel.centerXAnchor.constraint(
                    equalTo: circularProgressView.centerXAnchor
                ),
                currentValueLabel.centerYAnchor
                    .constraint(
                        equalTo: circularProgressView.centerYAnchor,
                        constant: -2.6 // Offset to visually center the text
                    ),
            ]
        )
    }

    func setupMaxValueConstraints() {
        // Position the max value label at the bottom center of the arc gap
        // The arc starts at 135° and spans 270°, leaving a gap from 45° to 135°
        // The center of the gap is at 90° (bottom of circle)

        // Calculate the radius to position the label
        let radius = Constants.circularViewSize / 2 - 26 // Same radius offset as in CircularProgressView

        // Position at the bottom of the circle (90 degrees)
        // For a circle centered at the view, 90 degrees is straight down
        NSLayoutConstraint.activate([
            maxValueLabel.centerXAnchor.constraint(equalTo: circularProgressView.centerXAnchor),
            // Position the label at the bottom of the circle, on the arc path
            maxValueLabel.centerYAnchor.constraint(
                equalTo: circularProgressView.centerYAnchor,
                constant: radius
            ),
        ])
    }

    func setupStatusLabelConstraints() {
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusLabel.topAnchor.constraint(
                equalTo: circularProgressView.bottomAnchor,
                constant: Constants.statusLabelBottomMargin
            ),
        ])
    }
}

// MARK: - Circular Progress View
final class CircularProgressView: UIView {

    // MARK: - Constants
    private enum Constants {
        static let radiusOffset: CGFloat = 15
        static let progressLineWidth: CGFloat = 6
        static let glowLineWidthOffset: CGFloat = 6
        static let tipCircleRadius: CGFloat = 5
        static let mainGlowSize: CGFloat = 25
        static let outerGlowSize: CGFloat = 30
        static let animationDuration: TimeInterval = 0.5

        static let startAngleDegrees: CGFloat = 135
        static let totalArcAngleDegrees: CGFloat = 270

        static var startAngle: CGFloat {
            startAngleDegrees * .pi / 180
        }

        static var totalArcAngle: CGFloat {
            totalArcAngleDegrees * .pi / 180
        }

        // Glow gradient configuration
        static let glowLocations: [NSNumber] = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
        static let glowAlphas: [CGFloat] = [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]
        static let outerGlowAlphas: [CGFloat] = [0.8, 0.6, 0.4, 0.2, 0.1, 0.0]
    }

    // MARK: - Properties
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

    // MARK: - Lifecycle
    override func layoutSubviews() {
        super.layoutSubviews()
        setupLayers()
        updateProgressAppearance()
    }

    // MARK: - Public Interface
    func setProgress(_ progress: Float, animated: Bool = false) {
        let clampedProgress = max(0, min(1, progress))
        currentProgress = clampedProgress

        if animated && animateProgress {
            animateProgressChange(to: clampedProgress)
        }

        progressLayer.strokeEnd = CGFloat(clampedProgress)
        updateProgressAppearance()
    }

    func setValue(
        _ value: Int,
        maxValue: Int = 100,
        state: AirQualityState,
        animated: Bool = false
    ) {
        let progress = Float(
            value
        ) / Float(
            maxValue
        )
        progressColor = state.color
        setProgress(
            progress,
            animated: animated
        )
    }
}

// MARK: - Progress Setup Methods
private extension CircularProgressView {

    func setupLayers() {
        clearExistingLayers()

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - Constants.radiusOffset
        let arcPath = createArcPath(center: center, radius: radius)

        setupBackgroundLayer(with: arcPath)
        setupProgressLayer(with: arcPath)
        setupTipLayers()
    }

    func clearExistingLayers() {
        [progressLayer, backgroundLayer, tipCircleLayer, tipGlowLayer].forEach {
            $0.removeFromSuperlayer()
        }
    }

    func createArcPath(center: CGPoint, radius: CGFloat) -> UIBezierPath {
        return UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: Constants.startAngle,
            endAngle: Constants.startAngle + Constants.totalArcAngle,
            clockwise: true
        )
    }

    func setupBackgroundLayer(with path: UIBezierPath) {
        backgroundLayer.path = path.cgPath
        backgroundLayer.strokeColor = RuuviColor.ruuviAQILinePlaceholderColor.color.cgColor
        backgroundLayer.lineWidth = Constants.progressLineWidth
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.lineCap = .round
        backgroundLayer.strokeEnd = 1.0
        layer.addSublayer(backgroundLayer)
    }

    func setupProgressLayer(with path: UIBezierPath) {
        progressLayer.path = path.cgPath
        progressLayer.strokeColor = progressColor.cgColor
        progressLayer.lineWidth = Constants.progressLineWidth
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineCap = .round
        layer.addSublayer(progressLayer)
    }

    func setupTipLayers() {
        layer.addSublayer(tipGlowLayer)
        tipCircleLayer.fillColor = progressColor.cgColor
        layer.addSublayer(tipCircleLayer)
    }

    func updateProgressAppearance() {
        progressLayer.strokeColor = progressColor.cgColor
        tipCircleLayer.fillColor = progressColor.cgColor
        updateTipPosition()
    }

    func animateProgressChange(to progress: Float) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = progressLayer.strokeEnd
        animation.toValue = progress
        animation.duration = Constants.animationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.updateTipPosition()
        }
        progressLayer.add(animation, forKey: "progress")
        CATransaction.commit()
    }
}

// MARK: - Tip Management
private extension CircularProgressView {

    func updateTipPosition() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - Constants.radiusOffset

        guard currentProgress > 0 else {
            clearTipElements()
            return
        }

        let tipCenter = calculateTipCenter(center: center, radius: radius)
        updateTipCircle(at: tipCenter)
        createGlowEffect(at: tipCenter)
    }

    func clearTipElements() {
        tipCircleLayer.path = nil
        tipGlowLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    func calculateTipCenter(center: CGPoint, radius: CGFloat) -> CGPoint {
        let progressAngle = Constants.startAngle + (Constants.totalArcAngle * CGFloat(currentProgress))
        let tipX = center.x + radius * cos(progressAngle)
        let tipY = center.y + radius * sin(progressAngle)
        return CGPoint(x: tipX, y: tipY)
    }

    func updateTipCircle(at center: CGPoint) {
        let tipPath = UIBezierPath(
            ovalIn: CGRect(
                x: center.x - Constants.tipCircleRadius,
                y: center.y - Constants.tipCircleRadius,
                width: Constants.tipCircleRadius * 2,
                height: Constants.tipCircleRadius * 2
            )
        )
        tipCircleLayer.path = tipPath.cgPath
    }

    func createGlowEffect(at center: CGPoint) {
        tipGlowLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let mainGlow = createGlowLayer(
            at: center,
            size: Constants.mainGlowSize,
            alphas: Constants.glowAlphas
        )
        tipGlowLayer.addSublayer(mainGlow)

        let outerGlow = createGlowLayer(
            at: center,
            size: Constants.outerGlowSize,
            alphas: Constants.outerGlowAlphas
        )
        tipGlowLayer.insertSublayer(outerGlow, at: 0)
    }

    func createGlowLayer(at center: CGPoint, size: CGFloat, alphas: [CGFloat]) -> CAGradientLayer {
        let glowGradient = CAGradientLayer()

        glowGradient.colors = alphas.map { progressColor.withAlphaComponent($0).cgColor }
        glowGradient.locations = Constants.glowLocations

        glowGradient.frame = CGRect(
            x: center.x - size/2,
            y: center.y - size/2,
            width: size,
            height: size
        )
        glowGradient.type = .radial
        glowGradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowGradient.endPoint = CGPoint(x: 1.0, y: 1.0)

        let glowMask = CAShapeLayer()
        let glowPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size))
        glowMask.path = glowPath.cgPath
        glowGradient.mask = glowMask

        return glowGradient
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

// swiftlint:enable file_length
