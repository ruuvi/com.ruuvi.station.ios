import UIKit

/// A character behind a card edge; the real card supplies the foreground occlusion.
final class DashboardHalloweenEffectsView: UIView {
    var cardFramesProvider: (() -> [CGRect])?

    private let stage = UIView()
    // Source timing: docs/assets/ruuvi-ghost-huu-timing.json. Preserve the full 640 × 720 canvases.
    private static let frameNames = [
        "01_peek_happy", "02_happy_full", "03_huu_transition",
        "04_huu_arms_up", "05_happy_full_return", "06_peek_happy_return",
    ]
    private static let frameDurations: [TimeInterval] = [0.22, 0.28, 0.14, 0.45, 0.25, 0.30]
    private static let sequenceDuration = frameDurations.reduce(0, +)
    private static let entranceDuration: TimeInterval = 0.25
    private static let animationDuration = sequenceDuration + entranceDuration * 2

    private let ghost = UIImageView(image: UIImage(named: "dashboard-halloween-huu-01_peek_happy"))
    private lazy var characterFrames: [CGImage] = loadCharacterFrames()
    private let occlusion = CAShapeLayer()
    private let edgeShadow = CAGradientLayer()
    private var animationEnabled = false
    private var previousBounds = CGRect.zero
    private var scheduledPeek: DispatchWorkItem?
    private var lastPeekEdge: PeekEdge?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        clipsToBounds = true
        stage.clipsToBounds = true
        addSubview(stage)
        ghost.contentMode = .scaleAspectFit
        ghost.alpha = 0
        ghost.layer.shadowColor = UIColor.black.cgColor
        ghost.layer.shadowOpacity = 0.18
        ghost.layer.shadowRadius = 8
        ghost.layer.shadowOffset = CGSize(width: 0, height: 5)
        stage.addSubview(ghost)
        occlusion.fillRule = .evenOdd
        stage.layer.mask = occlusion
        edgeShadow.type = .radial
        edgeShadow.colors = [UIColor.black.withAlphaComponent(0.3).cgColor, UIColor.clear.cgColor]
        edgeShadow.startPoint = CGPoint(x: 0.5, y: 0.5)
        edgeShadow.endPoint = CGPoint(x: 1, y: 1)
        edgeShadow.opacity = 0
        layer.addSublayer(edgeShadow)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        scheduledPeek?.cancel()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if previousBounds != bounds {
            previousBounds = bounds
            restartPeeking(after: 1)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        restartPeeking(after: 1)
    }

    func setAnimationEnabled(_ enabled: Bool) {
        guard animationEnabled != enabled else { return }
        animationEnabled = enabled
        restartPeeking(after: 1)
    }

    func pauseForInteraction() {
        restartPeeking(after: 3)
    }

    private func restartPeeking(after delay: TimeInterval) {
        scheduledPeek?.cancel()
        scheduledPeek = nil
        ghost.layer.removeAllAnimations()
        edgeShadow.removeAllAnimations()
        ghost.alpha = 0
        guard animationEnabled, window != nil, !bounds.isEmpty, ghost.image != nil else { return }
        schedulePeek(after: delay)
    }

    private func schedulePeek(after delay: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.animationEnabled, self.window != nil else { return }
            let candidates = (self.cardFramesProvider?() ?? []).filter {
                self.bounds.contains($0) && $0.width >= 110 && $0.height >= 100
            }
            let availableEdges = PeekEdge.allCases.filter { edge in
                candidates.contains { self.canPeek(behind: $0, from: edge) }
            }
            let differentEdges = availableEdges.filter { $0 != self.lastPeekEdge }
            guard let edge = (differentEdges.isEmpty ? availableEdges : differentEdges).randomElement(),
                  let card = candidates.filter({ self.canPeek(behind: $0, from: edge) }).randomElement() else {
                self.schedulePeek(after: 3)
                return
            }
            self.lastPeekEdge = edge
            self.peek(behind: card, from: edge)
            self.schedulePeek(after: 13)
        }
        scheduledPeek = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func canPeek(behind card: CGRect, from edge: PeekEdge) -> Bool {
        edge.availableSpace(for: card, in: bounds) >= characterSize(for: card, edge: edge).height * 0.82 + 12
    }

    private func peek(behind card: CGRect, from edge: PeekEdge) {
        let size = characterSize(for: card, edge: edge)
        let edgePoint = edge.point(on: card)
        let stageFrame = edge.stageFrame(for: card, in: bounds)
        let localCard = card.offsetBy(dx: -stageFrame.minX, dy: -stageFrame.minY)
        let hidden = CGPoint(
            x: edgePoint.x - stageFrame.minX - edge.normal.x * (size.height / 2 + 12),
            y: edgePoint.y - stageFrame.minY - edge.normal.y * (size.height / 2 + 12)
        )
        configureStage(frame: stageFrame, card: localCard, size: size, hidden: hidden, rotation: edge.rotation)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let shadowSize = edge.isHorizontal ? CGSize(width: 130, height: 14) : CGSize(width: 14, height: 130)
        edgeShadow.frame = CGRect(
            x: edgePoint.x - shadowSize.width / 2, y: edgePoint.y - shadowSize.height / 2,
            width: shadowSize.width, height: shadowSize.height
        )
        CATransaction.commit()
        animatePeek(from: hidden, height: size.height, edge: edge)
    }

    private func characterSize(for card: CGRect, edge: PeekEdge) -> CGSize {
        let width = min(250, (edge.isHorizontal ? card.width : card.height) * 0.94)
        return CGSize(width: width, height: width * 720 / 640)
    }

    private func configureStage(frame: CGRect, card: CGRect, size: CGSize, hidden: CGPoint, rotation: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        stage.frame = frame
        occlusion.frame = stage.bounds
        let mask = UIBezierPath(rect: stage.bounds)
        mask.append(UIBezierPath(roundedRect: card, cornerRadius: 12))
        occlusion.path = mask.cgPath
        ghost.transform = .identity
        ghost.bounds = CGRect(origin: .zero, size: size)
        ghost.center = hidden
        ghost.transform = CGAffineTransform(rotationAngle: rotation)
        ghost.alpha = 1
        CATransaction.commit()
    }

    private func movementTimes() -> [TimeInterval] {
        var elapsed = Self.entranceDuration
        var times: [TimeInterval] = [0, elapsed]
        for frameDuration in Self.frameDurations {
            elapsed += frameDuration
            times.append(elapsed)
        }
        times.append(Self.animationDuration)
        return times
    }

    private func animatePeek(from hidden: CGPoint, height: CGFloat, edge: PeekEdge) {
        let duration = Self.animationDuration
        // The PNGs already contain the peek/rise poses. Move the shared canvas into place once,
        // with small bounces after the two happy poses, rather than adding another hide-and-seek cycle.
        let times = movementTimes()
        let keyTimes = times.map { NSNumber(value: $0 / duration) }
        let amounts: [CGFloat] = [0, 0.78, 0.78, 0.80, 0.78, 0.78, 0.80, 0.78, 0]
        let sideways: [CGFloat] = [0, 0, -2, 0, 2, 0, -2, 0, 0]
        let positions = CAKeyframeAnimation(keyPath: "position")
        positions.keyTimes = keyTimes
        positions.values = amounts.enumerated().map { index, amount in
            NSValue(cgPoint: CGPoint(
                x: hidden.x + edge.normal.x * height * amount - edge.normal.y * sideways[index],
                y: hidden.y + edge.normal.y * height * amount + edge.normal.x * sideways[index]
            ))
        }
        positions.timingFunctions = times.dropLast().indices.map { index in
            let easing: CAMediaTimingFunctionName = index == 0 ? .easeOut :
                (index == times.count - 2 ? .easeIn : .easeInEaseOut)
            return CAMediaTimingFunction(name: easing)
        }
        let tilts: [CGFloat] = [0, -0.03, 0, 0.03, 0, -0.03, 0.02, 0, 0]
        let scales: [CGFloat] = [0.98, 1, 1, 1.02, 1, 1, 1.02, 1, 0.98]
        let curiosity = CAKeyframeAnimation(keyPath: "transform")
        curiosity.keyTimes = keyTimes
        curiosity.values = tilts.enumerated().map { index, tilt in
            NSValue(caTransform3D: CATransform3DConcat(
                CATransform3DMakeRotation(edge.rotation + tilt, 0, 0, 1),
                CATransform3DMakeScale(scales[index], 1 / scales[index], 1)
            ))
        }
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]
        fade.keyTimes = [0, 0.06, 0.94, 1]
        let animation = CAAnimationGroup()
        animation.animations = [positions, curiosity, fade]
        [positions, curiosity, fade].forEach { $0.duration = duration }
        if let character = characterAnimation() {
            animation.animations?.append(character)
        }
        animation.duration = duration
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        ghost.layer.add(animation, forKey: "hideAndSeek")
        let shadow = CAKeyframeAnimation(keyPath: "opacity")
        shadow.values = [0, 0.3, 0.3, 0.35, 0.4, 0.4, 0.35, 0.3, 0]
        shadow.keyTimes = keyTimes
        shadow.duration = duration
        edgeShadow.add(shadow, forKey: "contactShadow")
    }

    /// Keep each source canvas intact so every frame shares the same bottom-center alignment.
    private func loadCharacterFrames() -> [CGImage] {
        Self.frameNames.compactMap { name in
            UIImage(named: "dashboard-halloween-huu-\(name)")?.cgImage
        }
    }

    private func characterAnimation() -> CAKeyframeAnimation? {
        guard characterFrames.count == Self.frameNames.count, let last = characterFrames.last else { return nil }
        let character = CAKeyframeAnimation(keyPath: "contents")
        character.values = characterFrames + [last]
        var elapsed: TimeInterval = 0
        var keyTimes: [NSNumber] = [0]
        for duration in Self.frameDurations {
            elapsed += duration
            keyTimes.append(NSNumber(value: elapsed / Self.sequenceDuration))
        }
        character.keyTimes = keyTimes
        character.calculationMode = .discrete
        character.beginTime = Self.entranceDuration
        character.duration = Self.sequenceDuration
        character.fillMode = .both
        return character
    }
}

private enum PeekEdge: CaseIterable {
    case top, bottom, left, right

    var normal: CGPoint {
        switch self {
        case .top: return CGPoint(x: 0, y: -1)
        case .bottom: return CGPoint(x: 0, y: 1)
        case .left: return CGPoint(x: -1, y: 0)
        case .right: return CGPoint(x: 1, y: 0)
        }
    }

    var rotation: CGFloat {
        switch self {
        case .top: return 0
        case .bottom: return .pi
        case .left: return -.pi / 2
        case .right: return .pi / 2
        }
    }

    var isHorizontal: Bool { self == .top || self == .bottom }

    func point(on card: CGRect) -> CGPoint {
        switch self {
        case .top: return CGPoint(x: card.midX, y: card.minY)
        case .bottom: return CGPoint(x: card.midX, y: card.maxY)
        case .left: return CGPoint(x: card.minX, y: card.midY)
        case .right: return CGPoint(x: card.maxX, y: card.midY)
        }
    }

    func stageFrame(for card: CGRect, in bounds: CGRect) -> CGRect {
        switch self {
        case .top:
            return CGRect(x: card.minX, y: bounds.minY, width: card.width, height: card.midY - bounds.minY)
        case .bottom:
            return CGRect(x: card.minX, y: card.midY, width: card.width, height: bounds.maxY - card.midY)
        case .left:
            return CGRect(x: bounds.minX, y: card.minY, width: card.midX - bounds.minX, height: card.height)
        case .right:
            return CGRect(x: card.midX, y: card.minY, width: bounds.maxX - card.midX, height: card.height)
        }
    }

    func availableSpace(for card: CGRect, in bounds: CGRect) -> CGFloat {
        switch self {
        case .top: return card.minY - bounds.minY
        case .bottom: return bounds.maxY - card.maxY
        case .left: return card.minX - bounds.minX
        case .right: return bounds.maxX - card.maxX
        }
    }
}
