import UIKit

public final class EdgeFadeView: UIView {
    enum Edge { case top, bottom }

    var baseColor: UIColor = .systemBackground {
      didSet { updateColors(for: progress) }
    }

    /// 0...1 opacity driven by scroll progress.
    var progress: CGFloat = 0 {
      didSet {
        let p = max(0, min(1, progress))
        updateColors(for: p)
        isHidden = p <= 0.001
      }
    }

    private let edge: Edge

    // swiftlint:disable:next force_cast
    private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }
    public override class var layerClass: AnyClass { CAGradientLayer.self }

    init(edge: Edge) {
      self.edge = edge
      super.init(frame: .zero)
      isUserInteractionEnabled = false
      gradientLayer.locations = [0, 1]
      gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
      gradientLayer.endPoint   = CGPoint(x: 0.5, y: 1.0)
      updateColors(for: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // Fade by adjusting the stops’ alpha (no layer.opacity).
    private func updateColors(for p: CGFloat) {
      let resolved = baseColor.resolvedColor(with: traitCollection)
      let maxAlpha = resolved.cgColor.alpha
      let head = resolved.withAlphaComponent(maxAlpha * p).cgColor
      let tail = resolved.withAlphaComponent(0).cgColor

      switch edge {
      case .top:    gradientLayer.colors = [head, tail]
      case .bottom: gradientLayer.colors = [tail, head]
      }
    }

    public override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
      super.traitCollectionDidChange(previousTraitCollection)
      updateColors(for: progress) // keep in sync for light/dark changes
    }
  }
