import UIKit

final class CardsSensorNameSwipeView: UIView {
    enum NavigationDirection {
        case previous
        case next
    }

    private enum Constants {
        static let completionProgress: CGFloat = 0.5
        static let completionVelocity: CGFloat = 600
        static let minimumAnimationDuration: TimeInterval = 0.12
        static let maximumAnimationDuration: TimeInterval = 0.22
    }

    private struct Configuration {
        let current: String
        let previous: String?
        let next: String?
    }

    var onNavigate: ((NavigationDirection) -> Bool)?
    var text: String? {
        currentNameLabel.text
    }

    private let currentNameLabel: UILabel
    private let adjacentNameLabel: UILabel
    private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePanGesture(_:))
        )
        return gesture
    }()

    private var configuration = Configuration(current: "", previous: nil, next: nil)
    private var pendingConfiguration: Configuration?
    private var navigationDirection: NavigationDirection?
    private var horizontalTranslation: CGFloat = 0
    private var cachedIntrinsicHeight: CGFloat = 0
    private var swipeIntrinsicHeight: CGFloat?
    private var isHandlingSwipe = false

    init(font: UIFont, numberOfLines: Int) {
        currentNameLabel = Self.makeLabel(font: font, numberOfLines: numberOfLines)
        adjacentNameLabel = Self.makeLabel(font: font, numberOfLines: numberOfLines)
        super.init(frame: .zero)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: max(
                swipeIntrinsicHeight ?? cachedIntrinsicHeight,
                currentNameLabel.font.lineHeight
            )
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateIntrinsicHeightIfNeeded()
        let width = bounds.width
        let currentHeight = labelHeight(currentNameLabel)
        currentNameLabel.frame = CGRect(
            x: horizontalTranslation,
            y: 0,
            width: width,
            height: currentHeight
        )

        guard let navigationDirection else {
            adjacentNameLabel.frame = .zero
            return
        }

        let adjacentOrigin = navigationDirection == .next ? width : -width
        adjacentNameLabel.frame = CGRect(
            x: adjacentOrigin + horizontalTranslation,
            y: 0,
            width: width,
            height: labelHeight(adjacentNameLabel)
        )
    }

    override func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard !isHandlingSwipe,
              let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer else {
            return false
        }

        let velocity = panGestureRecognizer.velocity(in: self)
        guard abs(velocity.x) > abs(velocity.y), velocity.x != 0 else { return false }
        return adjacentName(for: direction(for: velocity.x)) != nil
    }

    func configure(current: String, previous: String?, next: String?) {
        let configuration = Configuration(
            current: current,
            previous: previous,
            next: next
        )
        guard !isHandlingSwipe else {
            pendingConfiguration = configuration
            return
        }
        apply(configuration)
    }
}

private extension CardsSensorNameSwipeView {
    static func makeLabel(font: UIFont, numberOfLines: Int) -> UILabel {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = numberOfLines
        label.font = font
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func setUpUI() {
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .header
        addSubview(currentNameLabel)
        addSubview(adjacentNameLabel)
        addGestureRecognizer(panGestureRecognizer)
    }

    private func apply(_ configuration: Configuration) {
        self.configuration = configuration
        currentNameLabel.text = configuration.current
        accessibilityLabel = configuration.current
        cachedIntrinsicHeight = labelHeight(currentNameLabel)
        swipeIntrinsicHeight = nil
        refreshLayout()
    }

    func updateIntrinsicHeightIfNeeded() {
        guard bounds.width > 0 else { return }
        let height = labelHeight(currentNameLabel)
        guard abs(height - cachedIntrinsicHeight) > 0.5 else { return }
        cachedIntrinsicHeight = height
        invalidateIntrinsicContentSize()
    }

    func labelHeight(_ label: UILabel) -> CGFloat {
        guard bounds.width > 0 else {
            return ceil(label.font.lineHeight)
        }
        return ceil(
            label.sizeThatFits(
                CGSize(width: bounds.width, height: .greatestFiniteMagnitude)
            ).height
        )
    }

    func adjacentName(for direction: NavigationDirection) -> String? {
        switch direction {
        case .previous:
            return configuration.previous
        case .next:
            return configuration.next
        }
    }

    func direction(for horizontalValue: CGFloat) -> NavigationDirection {
        horizontalValue > 0 ? .previous : .next
    }

    func updateSwipe(translation: CGFloat) {
        guard bounds.width > 0 else { return }
        let direction = direction(for: translation)
        guard let adjacentName = adjacentName(for: direction) else {
            horizontalTranslation = 0
            navigationDirection = nil
            swipeIntrinsicHeight = nil
            refreshLayout()
            return
        }

        if navigationDirection != direction {
            navigationDirection = direction
            adjacentNameLabel.text = adjacentName
        }
        horizontalTranslation = min(max(translation, -bounds.width), bounds.width)
        let progress = abs(horizontalTranslation) / bounds.width
        let adjacentHeight = labelHeight(adjacentNameLabel)
        swipeIntrinsicHeight = cachedIntrinsicHeight +
            (adjacentHeight - cachedIntrinsicHeight) * progress
        refreshLayout()
    }

    func shouldCompleteSwipe(velocity: CGFloat) -> Bool {
        guard bounds.width > 0 else { return false }
        let progress = abs(horizontalTranslation) / bounds.width
        let velocityMatchesDirection = velocity * horizontalTranslation >= 0
        let hasCompletionVelocity = abs(velocity) >= Constants.completionVelocity &&
            velocityMatchesDirection
        return progress >= Constants.completionProgress || hasCompletionVelocity
    }

    func finishSwipe(velocity: CGFloat) {
        guard let navigationDirection,
              shouldCompleteSwipe(velocity: velocity) else {
            animateBackToCurrentName()
            return
        }

        let targetTranslation = navigationDirection == .next ? -bounds.width : bounds.width
        let remainingProgress = 1 - min(abs(horizontalTranslation) / bounds.width, 1)
        let duration = animationDuration(for: remainingProgress)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: {
                self.horizontalTranslation = targetTranslation
                self.swipeIntrinsicHeight = self.labelHeight(self.adjacentNameLabel)
                self.refreshLayout()
            },
            completion: { _ in
                let navigationAccepted = self.onNavigate?(navigationDirection) ?? false
                if navigationAccepted {
                    self.completeTransition()
                } else {
                    self.animateBackToCurrentName()
                }
            }
        )
    }

    func animateBackToCurrentName() {
        let progress = bounds.width > 0 ? min(abs(horizontalTranslation) / bounds.width, 1) : 0
        let duration = animationDuration(for: progress)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: {
                self.horizontalTranslation = 0
                self.swipeIntrinsicHeight = nil
                self.refreshLayout()
            },
            completion: { _ in
                self.completeTransition()
            }
        )
    }

    func animationDuration(for progress: CGFloat) -> TimeInterval {
        let duration = Constants.maximumAnimationDuration * TimeInterval(progress)
        return min(max(duration, Constants.minimumAnimationDuration), Constants.maximumAnimationDuration)
    }

    func completeTransition() {
        horizontalTranslation = 0
        navigationDirection = nil
        adjacentNameLabel.text = nil
        swipeIntrinsicHeight = nil
        isHandlingSwipe = false

        if let pendingConfiguration {
            self.pendingConfiguration = nil
            apply(pendingConfiguration)
        } else {
            refreshLayout()
        }
    }

    func refreshLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        superview?.layoutIfNeeded()
        layoutIfNeeded()
    }

    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            isHandlingSwipe = true
        case .changed:
            updateSwipe(translation: gesture.translation(in: self).x)
        case .ended:
            finishSwipe(velocity: gesture.velocity(in: self).x)
        case .cancelled, .failed:
            animateBackToCurrentName()
        case .possible:
            break
        @unknown default:
            animateBackToCurrentName()
        }
    }
}
