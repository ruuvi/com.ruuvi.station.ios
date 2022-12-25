import UIKit

class RUAnimatingDotsView: UIView {

    // Public properties
    public var baseline: CGFloat = 0
    public var dotXOffset: CGFloat = 4.0
    public var dotSize: CGFloat = 4.0
    public var dotSpacing: CGFloat = 8.0

    // Private
    private let animationLayer = CAReplicatorLayer()
    private let dotLayer = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        animationLayer.addSublayer(dotLayer)
        layer.addSublayer(animationLayer)
    }
}

// MARK: - PUBLIC
extension RUAnimatingDotsView {
    public func startAnimating() {
        dotLayer.frame = CGRect(x: dotXOffset,
                                y: self.frame.height/2 + dotSize/2,
                                width: dotSize,
                                height: dotSize)
        dotLayer.cornerRadius = dotLayer.frame.width / 2.0
        dotLayer.backgroundColor = RuuviColor.ruuviTextColor?.cgColor

        animationLayer.instanceCount = 3
        animationLayer.instanceTransform = CATransform3DMakeTranslation(dotSpacing, 0, 0)

        let animation = CABasicAnimation(keyPath: #keyPath(CALayer.opacity))
        animation.fromValue = 1.0
        animation.toValue = 0.2
        animation.duration = 1
        animation.repeatCount = .infinity
        dotLayer.add(animation, forKey: nil)

        animationLayer.instanceDelay = animation.duration / Double(animationLayer.instanceCount)
    }

    public func stopAnimating() {
        animationLayer.instanceCount = 0
        dotLayer.backgroundColor = UIColor.clear.cgColor
        dotLayer.removeAllAnimations()
        animationLayer.removeAllAnimations()
        layer.removeAllAnimations()
        layoutIfNeeded()
    }
}
