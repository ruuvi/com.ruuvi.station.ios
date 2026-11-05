import UIKit

class CardsBackgroundView: UIView {
    private lazy var cardImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = .clear
        return iv
    }()

    private lazy var overlayView = CardsRadialScrimView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setUpUI() {
        clipsToBounds = true

        addSubview(cardImageView)
        cardImageView.fillSuperview()

        addSubview(overlayView)
        overlayView.fillSuperview()
    }
}

extension CardsBackgroundView {
    func setBackgroundImage(
        with image: UIImage?,
        isDashboard: Bool = true,
        withAnimation: Bool = true
    ) {
        overlayView.style = isDashboard ? .dashboard : .fullCard
        guard image != cardImageView.image else { return }
        if withAnimation {
            UIView.transition(
                with: cardImageView,
                duration: 0.3,
                options: .transitionCrossDissolve,
                animations: { [weak self] in
                    self?.cardImageView.image = image
                },
                completion: nil
            )
        } else {
            cardImageView.image = image
        }
    }

    func backgroundImage() -> UIImage? {
        return cardImageView.image
    }
}

/// Black radial gradient drawn over the sensor image so the card content stays readable.
/// It is clear near the right edge and darkens towards the left edge and the corners.
private final class CardsRadialScrimView: UIView {
    enum Style {
        /// Fitted to the old `tag_bg_layer` image: an ellipse that stretches with the view,
        /// clear at the right edge 42% of the way down.
        case dashboard
        /// From the design spec: a circle whose diameter is 170% of the view's width, with its
        /// left edge 15% of the width in from the view's left edge (which puts its center on the
        /// right edge) and its center 33.3% of the height down.
        case fullCard
    }

    var style: Style = .dashboard {
        didSet {
            if style != oldValue { setNeedsLayout() }
        }
    }

    /// Position along the radius (0 = center, 1 = edge) and black opacity at that position.
    private typealias Stop = (location: CGFloat, alpha: CGFloat)

    /// Gradient shape in points. Outside the edge, the last stop's opacity continues.
    private struct Shape {
        let center: CGPoint
        let radius: CGSize
        let stops: [Stop]
    }

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        (layer as? CAGradientLayer)?.type = .radial
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateGradient()
    }

    private func shape(for size: CGSize) -> Shape {
        switch style {
        case .dashboard:
            return Shape(
                center: CGPoint(x: size.width * 1.0, y: size.height * 0.42),
                radius: CGSize(width: size.width * 1.404, height: size.height * 0.826),
                stops: [
                    (0.00, 0.02),
                    (0.14, 0.05),
                    (0.24, 0.12),
                    (0.49, 0.38),
                    (0.69, 0.54),
                    (0.79, 0.65),
                    (0.89, 0.69),
                    (1.00, 0.70),
                ]
            )
        case .fullCard:
            let radius = size.width * 1.7 / 2
            return Shape(
                center: CGPoint(x: size.width * 0.15 + radius, y: size.height * 0.333),
                radius: CGSize(width: radius, height: radius),
                stops: [
                    (0.00, 0.05),
                    (0.36, 0.375),
                    (1.00, 0.70),
                ]
            )
        }
    }

    /// Recalculated on every layout because the full card's circle is sized in points.
    private func updateGradient() {
        guard let gradientLayer = layer as? CAGradientLayer,
              bounds.width > 0, bounds.height > 0 else { return }
        let size = bounds.size
        let shape = shape(for: size)

        // If a corner lies outside the edge, draw the gradient out to that corner and pull the stops
        // in by the same factor, so the area outside gets the last stop's opacity from an explicit
        // stop instead of relying on how the renderer fills beyond a radial gradient's edge.
        let farthestCorner = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height),
            CGPoint(x: size.width, y: size.height),
        ]
        .map {
            hypot(
                ($0.x - shape.center.x) / shape.radius.width,
                ($0.y - shape.center.y) / shape.radius.height
            )
        }
        .max() ?? 1
        let scale = max(1, farthestCorner)

        var stops = shape.stops.map { (location: $0.location / scale, alpha: $0.alpha) }
        if scale > 1, let last = shape.stops.last {
            stops.append((location: 1, alpha: last.alpha))
        }

        // Radial gradients use unit coordinates: startPoint is the center and
        // endPoint - startPoint is the radius along each axis.
        gradientLayer.startPoint = CGPoint(
            x: shape.center.x / size.width,
            y: shape.center.y / size.height
        )
        gradientLayer.endPoint = CGPoint(
            x: (shape.center.x + shape.radius.width * scale) / size.width,
            y: (shape.center.y + shape.radius.height * scale) / size.height
        )
        gradientLayer.colors = stops.map { UIColor.black.withAlphaComponent($0.alpha).cgColor }
        gradientLayer.locations = stops.map { NSNumber(value: Double($0.location)) }
    }
}
