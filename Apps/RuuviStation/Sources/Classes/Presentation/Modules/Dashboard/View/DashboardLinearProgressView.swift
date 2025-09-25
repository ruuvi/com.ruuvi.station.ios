// swiftlint:disable file_length

import RuuviLocalization
import RuuviOntology
import UIKit

// MARK: - Linear Progress View

// swiftlint:disable:next type_body_length
class DashboardLinearProgressView: UIView {

    // MARK: - Layout Constants

    private struct Constants {
        static let padding: CGFloat = 5.5
        static let mainGlowSize: CGFloat = 11
        static let outerGlowSize: CGFloat = 16
        static let animationDuration: TimeInterval = 0.5
        static let progressBarCornerRadius: CGFloat = 4
    }

    // MARK: - UI Components

    private lazy var progressBackgroundLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = RuuviColor.ruuviAQILinePlaceholderColor.color.cgColor
        layer.strokeColor = UIColor.clear.cgColor
        return layer
    }()

    private lazy var progressLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = RuuviColor.ruuviAQILinePlaceholderColor.color.cgColor
        layer.strokeColor = UIColor.clear.cgColor
        return layer
    }()

    private lazy var tipCircleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        return layer
    }()

    private lazy var tipGlowLayer = CAShapeLayer()

    private var currentProgress: Float = 0

    var progressColor: UIColor = RuuviColor.ruuviAQILinePlaceholderColor.color {
        didSet {
            updateProgressAppearance()
        }
    }

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

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        setupLayers()
        updateProgressAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            progressBackgroundLayer.fillColor = RuuviColor.ruuviAQILinePlaceholderColor.color.cgColor
        }
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: 16)
    }

    // MARK: - Setup

    private func setupUI() {
        // Make sure the view has a clear background
        backgroundColor = .clear
        setupLayers()
    }

    private func setupLayers() {
        // Clear existing layers
        progressBackgroundLayer.removeFromSuperlayer()
        progressLayer.removeFromSuperlayer()
        tipCircleLayer.removeFromSuperlayer()
        tipGlowLayer.removeFromSuperlayer()

        let progressBarRect = getProgressBarRect()

        // Only proceed if we have valid bounds
        guard progressBarRect.width > 0 && progressBarRect.height > 0 else {
            return
        }

        // Background layer - full progress bar background
        let backgroundPath = UIBezierPath(
            roundedRect: progressBarRect,
            cornerRadius: min(Constants.progressBarCornerRadius, progressBarRect.height / 2)
        )
        progressBackgroundLayer.path = backgroundPath.cgPath
        layer.addSublayer(progressBackgroundLayer)

        // Progress layer - filled portion
        layer.addSublayer(progressLayer)

        // Glow layer - add before tip circle so glow appears behind
        layer.addSublayer(tipGlowLayer)

        // Tip circle layer - on top
        layer.addSublayer(tipCircleLayer)
    }

    private func getProgressBarRect() -> CGRect {
        // Calculate the actual progress bar rect with padding
        let insetRect = bounds.insetBy(dx: Constants.padding, dy: Constants.padding)

        // Make sure we have positive dimensions
        guard insetRect.width > 0 && insetRect.height > 0 else {
            // If the inset rect is invalid, use the full bounds with minimal padding
            let minPadding = min(Constants.padding, bounds.width / 4, bounds.height / 4)
            return bounds.insetBy(dx: minPadding, dy: minPadding)
        }

        return insetRect
    }

    // MARK: - Progress Updates

    private func updateProgressAppearance() {
        // Update progress layer color
        progressLayer.fillColor = progressColor.cgColor

        // Update tip colors
        tipCircleLayer.fillColor = progressColor.cgColor

        // Update progress bar fill and tip position
        updateProgressFill()
        updateTipPosition()
    }

    private func updateProgressFill() {
        let progressBarRect = getProgressBarRect()

        // Only proceed if we have valid bounds
        guard progressBarRect.width > 0 && progressBarRect.height > 0 else {
            return
        }

        let progressWidth = progressBarRect.width * CGFloat(currentProgress)

        let progressRect = CGRect(
            x: progressBarRect.minX,
            y: progressBarRect.minY,
            width: max(0, progressWidth),
            height: progressBarRect.height
        )

        let progressPath = UIBezierPath(
            roundedRect: progressRect,
            cornerRadius: min(Constants.progressBarCornerRadius, progressBarRect.height / 2)
        )
        progressLayer.path = progressPath.cgPath
    }

    private func updateTipPosition() {
        let progressBarRect = getProgressBarRect()

        // Only proceed if we have valid bounds
        guard progressBarRect.width > 0 && progressBarRect.height > 0 else {
            tipCircleLayer.path = nil
            tipGlowLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
            return
        }

        // If progress is zero, position tip at 0.5% position to keep it visible
        // and within frame.
        let adjustedProgress = currentProgress == 0 ? 0.05 : currentProgress
        let progressWidth = progressBarRect.width * CGFloat(adjustedProgress)
        let tipRadius = min(progressBarRect.height / 2, 10) // Cap the tip radius

        let tipX = progressBarRect.minX + progressWidth - tipRadius
        let tipY = progressBarRect.midY
        let tipCenter = CGPoint(x: tipX, y: tipY)

        // Update tip circle (main dot)
        let tipPath = UIBezierPath(
            arcCenter: tipCenter,
            radius: tipRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        tipCircleLayer.path = tipPath.cgPath

        // Create glow effect
        createGlowEffect(at: tipCenter, radius: tipRadius)
    }

    // swiftlint:disable:next function_body_length
    private func createGlowEffect(at center: CGPoint, radius: CGFloat) {
        // Clear existing glow layers efficiently
        tipGlowLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        // Layer 1: Intense core for light bulb effect
        let coreGlow = CAGradientLayer()
        coreGlow.colors = [
            progressColor.cgColor,
            progressColor.withAlphaComponent(0.9).cgColor,
            progressColor.withAlphaComponent(0.8).cgColor,
            progressColor.withAlphaComponent(0.4).cgColor,
            progressColor.withAlphaComponent(0.0).cgColor,
        ]
        coreGlow.locations = [0.0, 0.1, 0.3, 0.6, 1.0]

        let coreSize: CGFloat = radius * 3
        coreGlow.frame = CGRect(
            x: center.x - coreSize / 2,
            y: center.y - coreSize / 2,
            width: coreSize,
            height: coreSize
        )
        coreGlow.type = .radial
        coreGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        coreGlow.endPoint = CGPoint(x: 1.0, y: 1.0)
        coreGlow.cornerRadius = coreSize / 2

        tipGlowLayer.addSublayer(coreGlow)

        // Layer 2: Main color glow
        let mainGlow = CAGradientLayer()
        mainGlow.colors = [
            progressColor.cgColor,
            progressColor.withAlphaComponent(0.9).cgColor,
            progressColor.withAlphaComponent(0.7).cgColor,
            progressColor.withAlphaComponent(0.4).cgColor,
            progressColor.withAlphaComponent(0.2).cgColor,
            progressColor.withAlphaComponent(0.0).cgColor,
        ]
        mainGlow.locations = [0.0, 0.15, 0.3, 0.5, 0.7, 1.0]

        let mainGlowSize = Constants.mainGlowSize * 1.5
        mainGlow.frame = CGRect(
            x: center.x - mainGlowSize / 2,
            y: center.y - mainGlowSize / 2,
            width: mainGlowSize,
            height: mainGlowSize
        )
        mainGlow.type = .radial
        mainGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        mainGlow.endPoint = CGPoint(x: 1.0, y: 1.0)
        mainGlow.cornerRadius = mainGlowSize / 2

        tipGlowLayer.insertSublayer(mainGlow, at: 0)

        // Layer 3: Outer ambient glow
        let outerGlow = CAGradientLayer()
        outerGlow.colors = [
            progressColor.withAlphaComponent(0.6).cgColor,
            progressColor.withAlphaComponent(0.4).cgColor,
            progressColor.withAlphaComponent(0.2).cgColor,
            progressColor.withAlphaComponent(0.1).cgColor,
            progressColor.withAlphaComponent(0.05).cgColor,
            progressColor.withAlphaComponent(0.0).cgColor,
        ]
        outerGlow.locations = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]

        let outerGlowSize = Constants.outerGlowSize
        outerGlow.frame = CGRect(
            x: center.x - outerGlowSize / 2,
            y: center.y - outerGlowSize / 2,
            width: outerGlowSize,
            height: outerGlowSize
        )
        outerGlow.type = .radial
        outerGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        outerGlow.endPoint = CGPoint(x: 1.0, y: 1.0)
        outerGlow.cornerRadius = outerGlowSize / 2

        tipGlowLayer.insertSublayer(outerGlow, at: 0)

        // Layer 4: Extra bright spot at center
        let brightSpot = CAGradientLayer()
        brightSpot.colors = [
            progressColor.cgColor,
            progressColor.withAlphaComponent(0.8).cgColor,
            progressColor.cgColor,
            progressColor.withAlphaComponent(0.0).cgColor,
        ]
        brightSpot.locations = [0.0, 0.2, 0.5, 1.0]

        let brightSpotSize = radius * 2.5
        brightSpot.frame = CGRect(
            x: center.x - brightSpotSize / 2,
            y: center.y - brightSpotSize / 2,
            width: brightSpotSize,
            height: brightSpotSize
        )
        brightSpot.type = .radial
        brightSpot.startPoint = CGPoint(x: 0.5, y: 0.5)
        brightSpot.endPoint = CGPoint(x: 1.0, y: 1.0)
        brightSpot.cornerRadius = brightSpotSize / 2

        // Use additive blend mode for brighter effect
        brightSpot.compositingFilter = "plusLighter"

        tipGlowLayer.addSublayer(brightSpot)
    }

    // MARK: - Public Methods

    func setProgress(_ progress: Float, animated: Bool = false) {
        let clampedProgress = max(0, min(1, progress))

        if animated && animateProgress {
            // Store the old progress for animation
            currentProgress = clampedProgress

            // Animate both progress fill and tip position
            CATransaction.begin()
            CATransaction.setAnimationDuration(Constants.animationDuration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

            // Animate progress fill
            let progressAnimation = CABasicAnimation(keyPath: "path")
            progressAnimation.fromValue = progressLayer.path
            progressAnimation.toValue = getProgressPath(for: clampedProgress).cgPath
            progressAnimation.duration = Constants.animationDuration
            progressAnimation.fillMode = .forwards
            progressAnimation.isRemovedOnCompletion = false

            progressLayer.add(progressAnimation, forKey: "progress")

            // Animate tip position
            let tipAnimation = CABasicAnimation(keyPath: "path")
            tipAnimation.fromValue = tipCircleLayer.path
            tipAnimation.toValue = getTipPath(for: clampedProgress).cgPath
            tipAnimation.duration = Constants.animationDuration
            tipAnimation.fillMode = .forwards
            tipAnimation.isRemovedOnCompletion = false

            tipCircleLayer.add(tipAnimation, forKey: "tipPosition")

            CATransaction.setCompletionBlock { [weak self] in
                self?.updateProgressFill()
                self?.updateTipPosition()
                // Remove animations after completion
                self?.progressLayer.removeAllAnimations()
                self?.tipCircleLayer.removeAllAnimations()
            }

            CATransaction.commit()
        } else {
            currentProgress = clampedProgress
            updateProgressFill()
            updateTipPosition()
        }
    }

    private func getProgressPath(for progress: Float) -> UIBezierPath {
        let progressBarRect = getProgressBarRect()
        let progressWidth = progressBarRect.width * CGFloat(progress)

        let progressRect = CGRect(
            x: progressBarRect.minX,
            y: progressBarRect.minY,
            width: max(0, progressWidth),
            height: progressBarRect.height
        )

        return UIBezierPath(
            roundedRect: progressRect,
            cornerRadius: min(Constants.progressBarCornerRadius, progressBarRect.height / 2)
        )
    }

    private func getTipPath(for progress: Float) -> UIBezierPath {
        let progressBarRect = getProgressBarRect()
        let progressWidth = progressBarRect.width * CGFloat(progress)
        let tipRadius = min(progressBarRect.height / 2, 10)

        // Position tip so its trailing edge aligns with progress bar's end
        let tipX = progressBarRect.minX + progressWidth - tipRadius
        let tipY = progressBarRect.midY
        let tipCenter = CGPoint(x: tipX, y: tipY)

        return UIBezierPath(
            arcCenter: tipCenter,
            radius: tipRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
    }

    func setValue(
        _ value: Int,
        maxValue: Int = 100,
        progressTintColor: UIColor?,
        animated: Bool = false
    ) {
        let progress = Float(value) / Float(maxValue)

        // If no color provided, use a default visible color for testing
        if let tintColor = progressTintColor {
            progressColor = tintColor
        } else {
            progressColor = RuuviColor.ruuviAQILinePlaceholderColor.color
        }

        setProgress(progress, animated: animated)
    }
}

// swiftlint:enable file_length
