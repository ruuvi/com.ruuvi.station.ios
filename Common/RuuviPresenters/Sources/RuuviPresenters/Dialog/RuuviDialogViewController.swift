import RuuviLocalization
import UIKit

/// Presents a reusable Ruuvi dialog over a dimmed screen. Actions are controlled by the caller.
public final class RuuviDialogViewController: UIViewController {
    public var onPrimaryAction: (() -> Void)?
    public var onSecondaryAction: (() -> Void)?
    public var onDidAppear: (() -> Void)?
    public var onDismiss: (() -> Void)?

    private let dialogView: RuuviDialogView
    private var heightConstraint: NSLayoutConstraint!

    /// Default placement: centered in the safe area.
    private var centeredConstraints: [NSLayoutConstraint] = []
    /// iPhone Duo, partially folded: the region beside the fold that the dialog is centered in.
    private let foldFreeRegionGuide = UILayoutGuide()
    private var foldFreeRegionConstraints: [NSLayoutConstraint] = []
    private var foldFreePlacementConstraints: [NSLayoutConstraint] = []
    private var isPlacedBesideFold = false

    public init(configuration: RuuviDialogConfiguration) {
        dialogView = RuuviDialogView(configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        isModalInPresentation = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.accessibilityViewIsModal = true
        view.addSubview(dialogView)
        dialogView.translatesAutoresizingMaskIntoConstraints = false
        let preferredWidth = dialogView.widthAnchor.constraint(equalToConstant: 340)
        preferredWidth.priority = UILayoutPriority(999)
        heightConstraint = dialogView.heightAnchor.constraint(equalToConstant: 1)
        centeredConstraints = [
            dialogView.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, constant: -48),
            dialogView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            dialogView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ]
        NSLayoutConstraint.activate([preferredWidth, heightConstraint] + centeredConstraints)
        dialogView.onPrimaryAction = { [weak self] in self?.onPrimaryAction?() }
        dialogView.onSecondaryAction = { [weak self] in self?.onSecondaryAction?() }
        setUpFoldAvoidance()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePlacementForFold()
        let placementFrame = isPlacedBesideFold
            ? foldFreeRegionGuide.layoutFrame
            : view.safeAreaLayoutGuide.layoutFrame
        let availableHeight = max(0, placementFrame.height - 32)
        let height = min(dialogView.preferredHeight(for: dialogView.bounds.width), availableHeight)
        if abs(heightConstraint.constant - height) > 0.5 {
            heightConstraint.constant = height
            view.layoutIfNeeded()
        }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        dialogView.focusTitle()
        onDidAppear?()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil {
            onDismiss?()
        }
    }

    public func configure(_ configuration: RuuviDialogConfiguration) {
        dialogView.configure(configuration)
        view.setNeedsLayout()
        if view.window != nil { dialogView.focusTitle() }
    }

    public func setLoading(_ loading: Bool) {
        dialogView.setLoading(loading)
    }

    public func showError(_ message: String?) {
        dialogView.showError(message)
        view.setNeedsLayout()
    }
}

// MARK: - iPhone Duo fold avoidance
private extension RuuviDialogViewController {
    /// A custom dialog doesn't move away from iPhone Duo's fold on its own (system alerts do), so
    /// while the device is partially folded it is centered in the region beside the fold. Without
    /// an active fold (always on iPhone and iPad) the original centered constraints stay active.
    func setUpFoldAvoidance() {
        view.addLayoutGuide(foldFreeRegionGuide)
        foldFreeRegionConstraints = [
            foldFreeRegionGuide.leftAnchor.constraint(equalTo: view.leftAnchor),
            foldFreeRegionGuide.topAnchor.constraint(equalTo: view.topAnchor),
            foldFreeRegionGuide.widthAnchor.constraint(equalToConstant: 0),
            foldFreeRegionGuide.heightAnchor.constraint(equalToConstant: 0),
        ]
        foldFreePlacementConstraints = [
            dialogView.widthAnchor.constraint(lessThanOrEqualTo: foldFreeRegionGuide.widthAnchor, constant: -48),
            dialogView.centerXAnchor.constraint(equalTo: foldFreeRegionGuide.centerXAnchor),
            dialogView.centerYAnchor.constraint(equalTo: foldFreeRegionGuide.centerYAnchor),
        ]
        if #available(iOS 27.1, *) {
            // Folding or unfolding doesn't change the view's size, so ask for a layout pass.
            view.addInteraction(UIHingeInteraction { [weak self] _, update in
                guard update.hinge != nil else { return }
                self?.view.setNeedsLayout()
            })
        }
    }

    func updatePlacementForFold() {
        guard let fold = RuuviDuoLayout.activeFolds(in: view).first else {
            if isPlacedBesideFold {
                NSLayoutConstraint.deactivate(foldFreePlacementConstraints + foldFreeRegionConstraints)
                NSLayoutConstraint.activate(centeredConstraints)
                isPlacedBesideFold = false
            }
            return
        }

        let region = foldFreeRegion(beside: fold)
        let constants = [region.minX, region.minY, region.width, region.height]
        for (constraint, constant) in zip(foldFreeRegionConstraints, constants)
        where abs(constraint.constant - constant) > 0.5 {
            constraint.constant = constant
        }
        if !isPlacedBesideFold {
            NSLayoutConstraint.deactivate(centeredConstraints)
            NSLayoutConstraint.activate(foldFreeRegionConstraints + foldFreePlacementConstraints)
            isPlacedBesideFold = true
        }
    }

    /// Below a horizontal fold (propped up like a laptop, interactive content belongs in the
    /// lower half), or on the trailing side of a vertical fold (held like a book, where the system
    /// moves alerts too).
    func foldFreeRegion(beside fold: CGRect) -> CGRect {
        let safe = view.safeAreaLayoutGuide.layoutFrame
        if fold.width >= fold.height {
            return CGRect(
                x: safe.minX,
                y: fold.maxY,
                width: safe.width,
                height: max(0, safe.maxY - fold.maxY)
            )
        }
        if view.effectiveUserInterfaceLayoutDirection == .rightToLeft {
            return CGRect(
                x: safe.minX,
                y: safe.minY,
                width: max(0, fold.minX - safe.minX),
                height: safe.height
            )
        }
        return CGRect(
            x: fold.maxX,
            y: safe.minY,
            width: max(0, safe.maxX - fold.maxX),
            height: safe.height
        )
    }
}
