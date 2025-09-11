import UIKit

// MARK: - ScrollViewEdgeFader
/// A helper class that adds top and bottom edge fading to any UIScrollView
public final class ScrollViewEdgeFader: NSObject {

    // MARK: - Configuration
    public struct Configuration {
        /// Height of the fade transition in points
        public var fadeTransitionHeight: CGFloat = 30

        /// Alpha component for the fade effect (0-1)
        public var fadeAlphaComponent: CGFloat = 0.3

        /// Multiplier for top fade gradient position
        public var topFadeMultiplier: CGFloat = 0.3

        /// Offset for bottom fade gradient position
        public var bottomFadeOffset: CGFloat = 0.04

        /// Whether to automatically update on scroll
        public var automaticallyUpdatesOnScroll: Bool = true

        /// Whether fading is enabled
        public var isEnabled: Bool = true

        public init() {}
    }

    // MARK: - Properties
    private weak var scrollView: UIScrollView?
    private var scrollViewObservation: NSKeyValueObservation?
    private var boundsObservation: NSKeyValueObservation?
    public var configuration: Configuration {
        didSet {
            if configuration.isEnabled {
                updateFadeMask()
            } else {
                removeFadeMask()
            }
        }
    }

    // MARK: - Initialization
    public init(
        scrollView: UIScrollView,
        configuration: Configuration = Configuration()
    ) {
        self.scrollView = scrollView
        self.configuration = configuration
        super.init()
        setup()
    }

    deinit {
        scrollViewObservation?
            .invalidate()
    }

    // MARK: - Setup
    private func setup() {
        guard let scrollView = scrollView else {
            return
        }

        if configuration.automaticallyUpdatesOnScroll {
            scrollView.delegate = self
        }

        // Observe content size changes
        scrollViewObservation = scrollView
            .observe(\.contentSize, options: [.new]) { [weak self] _, _ in
                self?.updateFadeMask()
            }

        // Also observe bounds changes
        boundsObservation = scrollView
            .observe(\.bounds, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.updateFadeMask()
                }
            }

        // Initial update with a slight delay
        DispatchQueue.main.async {
            self.updateFadeMask()
        }
    }

    // MARK: - Public Methods

    /// Manually update the fade mask (useful if automaticallyUpdatesOnScroll is false)
    public func updateFadeMask() {
        guard configuration.isEnabled,
              let scrollView = scrollView else {
            removeFadeMask()
            return
        }

        let isScrollable = scrollView.contentSize.height > scrollView.bounds.height

        guard isScrollable else {
            removeFadeMask()
            return
        }

        applyFadeMask(
            to: scrollView
        )
    }

    /// Remove the fade mask
    public func removeFadeMask() {
        scrollView?.layer.mask = nil
    }

    // MARK: - Private Methods

    // swiftlint:disable:next function_body_length
    private func applyFadeMask(
        to scrollView: UIScrollView
    ) {
        scrollView.layoutIfNeeded()

        guard scrollView.bounds.width > 0 && scrollView.bounds.height > 0 else {
            // Bounds not ready yet, try again later
            DispatchQueue.main.async { [weak self] in
                self?.updateFadeMask()
            }
            return
        }

        let contentOffset = max(
            0,
            scrollView.contentOffset.y
        )
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.bounds.height
        let maxScrollOffset = max(
            0,
            contentHeight - scrollViewHeight
        )

        let hasContentAbove = contentOffset > 0
        let remainingContentBelow = maxScrollOffset - contentOffset
        let hasContentBelow = remainingContentBelow > 0

        guard hasContentAbove || hasContentBelow else {
            scrollView.layer.mask = nil
            return
        }

        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = scrollView.bounds

        var colors: [CGColor] = []
        var locations: [NSNumber] = []

        let fadeHeight = configuration.fadeTransitionHeight

        if hasContentAbove {
            let fadeProgress = min(
                contentOffset / fadeHeight,
                1.0
            )
            let topFadeEnd = fadeHeight / scrollViewHeight

            colors
                .append(
                    UIColor.clear.cgColor
                )
            colors
                .append(
                    UIColor.black.withAlphaComponent(
                        configuration.fadeAlphaComponent * fadeProgress
                    ).cgColor
                )
            colors
                .append(
                    UIColor.black.cgColor
                )

            locations
                .append(
                    0.0
                )
            locations
                .append(
                    NSNumber(
                        value: topFadeEnd * configuration.topFadeMultiplier
                    )
                )
            locations
                .append(
                    NSNumber(
                        value: topFadeEnd
                    )
                )
        } else {
            colors
                .append(
                    UIColor.black.cgColor
                )
            locations
                .append(
                    0.0
                )
        }

        if hasContentBelow {
            let fadeProgress = min(
                remainingContentBelow / fadeHeight,
                1.0
            )
            let bottomFadeStart = 1.0 - (
                fadeHeight / scrollViewHeight
            )

            if colors.count == 1 || locations.last!.doubleValue < bottomFadeStart {
                colors
                    .append(
                        UIColor.black.cgColor
                    )
                locations
                    .append(
                        NSNumber(
                            value: bottomFadeStart
                        )
                    )
            }

            colors
                .append(
                    UIColor.black.withAlphaComponent(
                        configuration.fadeAlphaComponent * fadeProgress
                    ).cgColor
                )
            colors
                .append(
                    UIColor.clear.cgColor
                )

            locations
                .append(
                    NSNumber(
                        value: bottomFadeStart + configuration.bottomFadeOffset
                    )
                )
            locations
                .append(
                    1.0
                )
        } else {
            colors
                .append(
                    UIColor.black.cgColor
                )
            locations
                .append(
                    1.0
                )
        }

        gradientLayer.colors = colors
        gradientLayer.locations = locations
        gradientLayer.startPoint = CGPoint(
            x: 0.5,
            y: 0.0
        )
        gradientLayer.endPoint = CGPoint(
            x: 0.5,
            y: 1.0
        )

        scrollView.layer.mask = gradientLayer
    }
}

// MARK: - UIScrollViewDelegate
extension ScrollViewEdgeFader: UIScrollViewDelegate {
    public func scrollViewDidScroll(
        _ scrollView: UIScrollView
    ) {
        guard configuration.automaticallyUpdatesOnScroll else {
            return
        }
        updateFadeMask()
    }
}

// MARK: - UIScrollView Extension
extension UIScrollView {

    private struct AssociatedKeys {
        static var edgeFaderKey: UInt8 = 0
    }

    /// The edge fader instance associated with this scroll view
    public var edgeFader: ScrollViewEdgeFader? {
        get {
            objc_getAssociatedObject(
                self,
                &AssociatedKeys.edgeFaderKey
            ) as? ScrollViewEdgeFader
        }
        set {
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.edgeFaderKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// Enable edge fading with default configuration
    @discardableResult
    public func enableEdgeFading(
        configuration: ScrollViewEdgeFader.Configuration = ScrollViewEdgeFader.Configuration()
    ) -> ScrollViewEdgeFader {
        let fader = ScrollViewEdgeFader(
            scrollView: self,
            configuration: configuration
        )
        self.edgeFader = fader
        return fader
    }

    /// Disable edge fading
    public func disableEdgeFading() {
        edgeFader?
            .removeFadeMask()
        edgeFader = nil
    }

    /// Update edge fading if enabled
    public func updateEdgeFading() {
        edgeFader?
            .updateFadeMask()
    }
}
