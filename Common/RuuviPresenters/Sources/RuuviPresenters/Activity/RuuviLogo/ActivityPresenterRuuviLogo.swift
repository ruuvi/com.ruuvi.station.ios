import UIKit

public final class ActivityPresenterRuuviLogo: NSObject {
    // Minimum duration to keep a status message on the screen.
    private let minDisplayTime: CFTimeInterval = 1.5
    // Animation duration for presenting and dismissing the activity indicator.
    private let animationDuration: CGFloat = 0.5
    // Vertical(top/bottom) padding for activity indicator depending on position.
    private let verticalPadding: CGFloat = 8

    private let activityPresenterViewProvider: ActivityPresenterViewProvider
    private let activityPresenterViewController: UIViewController
    private let stateHolder = ActivityPresenterStateHolder()

    private var activityPresenterPosition: ActivityPresenterPosition = .bottom
    private var stateStartTime: CFTimeInterval?
    private var pendingDismissWorkItem: DispatchWorkItem?
    private var dismissalGeneration = 0
    private var currentState: ActivityPresenterState = .dismiss
    private weak var hostView: UIView?
    /// `true` from the start of a presentation until a dismissal starts.
    private var isPresented = false
    /// Holds the toast view in the host view and reports the host's safe area changes, so the
    /// toast's resting offset follows them.
    private lazy var containerView: ActivityPresenterContainerView = {
        let container = ActivityPresenterContainerView()
        container.backgroundColor = .clear
        if let toastView = activityPresenterViewController.view {
            container.addSubview(toastView)
            setupConstraints(for: toastView, in: container)
        }
        container.onSafeAreaInsetsChange = { [weak self] in
            self?.updateRestingOffsetIfPresented()
        }
        return container
    }()
    private lazy var successTouchRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer()
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = self
        return recognizer
    }()

    public override init() {
        activityPresenterViewProvider = ActivityPresenterViewProvider(stateHolder: stateHolder)
        activityPresenterViewController = activityPresenterViewProvider.makeViewController()
        super.init()
        activityPresenterViewController.view.backgroundColor = .clear
    }
}

extension ActivityPresenterRuuviLogo: ActivityPresenter {
    public func show(
        with state: ActivityPresenterState,
        atPosition position: ActivityPresenterPosition
    ) {
        cancelPendingDismissal()
        activityPresenterPosition = position
        activityPresenterViewProvider.updatePosition(position)
        stateStartTime = CFAbsoluteTimeGetCurrent()
        currentState = state
        guard let topController = RuuviPresenterHelper.topViewController(),
              let toastView = activityPresenterViewController.view else {
            return
        }

        hostView = topController.view
        if containerView.superview !== topController.view {
            containerView.removeFromSuperview()
            topController.view.addSubview(containerView)
            setupConstraints(for: containerView, in: topController.view)
        } else {
            topController.view.bringSubviewToFront(containerView)
        }
        updateInteraction(for: state)
        animateActivityViewPresentation(toastView, atPosition: position)

        activityPresenterViewProvider.updateState(state)
    }

    public func update(with state: ActivityPresenterState) {
        cancelPendingDismissal()
        stateStartTime = CFAbsoluteTimeGetCurrent()
        currentState = state
        updateInteraction(for: state)
        activityPresenterViewProvider.updateState(state)
    }

    public func dismiss(immediately: Bool) {
        cancelPendingDismissal()
        guard let toastView = activityPresenterViewController.view else {
            return
        }

        let displayTime = CFAbsoluteTimeGetCurrent() - (stateStartTime ?? 0)
        let additionalWaitTime = immediately ? 0 : max(minDisplayTime - displayTime, 0)
        let generation = dismissalGeneration
        let workItem = DispatchWorkItem { [weak self, weak toastView] in
            guard let self,
                  self.dismissalGeneration == generation,
                  let toastView else {
                return
            }
            self.animateActivityViewDismissal(
                toastView,
                generation: generation
            )
        }
        pendingDismissWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + additionalWaitTime,
            execute: workItem
        )
    }
}

extension ActivityPresenterRuuviLogo {
    private func cancelPendingDismissal() {
        dismissalGeneration += 1
        pendingDismissWorkItem?.cancel()
        pendingDismissWorkItem = nil
    }

    private func updateInteraction(for state: ActivityPresenterState) {
        if case .success = state {
            activityPresenterViewController.view.isUserInteractionEnabled = false
            if containerView.superview != nil,
               let hostView,
               successTouchRecognizer.view !== hostView {
                removeSuccessTouchRecognizer()
                hostView.addGestureRecognizer(successTouchRecognizer)
            }
        } else {
            removeSuccessTouchRecognizer()
            activityPresenterViewController.view.isUserInteractionEnabled = true
        }
    }

    private func removeSuccessTouchRecognizer() {
        successTouchRecognizer.view?.removeGestureRecognizer(successTouchRecognizer)
    }

    private func dismissSuccessToastImmediately() {
        guard case .success = currentState else { return }
        cancelPendingDismissal()
        removeSuccessTouchRecognizer()
        isPresented = false
        containerView.removeFromSuperview()
        activityPresenterViewProvider.updateState(.dismiss)
        currentState = .dismiss
        hostView = nil
    }

    private func setupConstraints(
        for view: UIView,
        in superview: UIView
    ) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(
                equalTo: superview.leadingAnchor
            ),
            view.trailingAnchor.constraint(
                equalTo: superview.trailingAnchor
            ),
            view.topAnchor.constraint(
                equalTo: superview.topAnchor
            ),
            view.bottomAnchor.constraint(
                equalTo: superview.bottomAnchor
            ),
        ])
    }

    private func animateActivityViewPresentation(
        _ view: UIView,
        atPosition position: ActivityPresenterPosition
    ) {
        isPresented = true
        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseOut]
        ) { [weak self] in
            guard let self = self else { return }
            view.transform = self.restingTransform(for: position)
        }
    }

    /// The toast's offset while it is shown: clear of the host view's safe area plus the padding.
    private func restingTransform(for position: ActivityPresenterPosition) -> CGAffineTransform {
        let insets = hostView?.safeAreaInsets ?? .zero
        switch position {
        case .top:
            return CGAffineTransform(translationX: 0, y: insets.top + verticalPadding)
        case .bottom:
            return CGAffineTransform(translationX: 0, y: -(insets.bottom + verticalPadding))
        case .center:
            return .identity
        }
    }

    /// Called when the host view's safe area changes (a resized or moved window, a changed bottom
    /// inset). Moves a shown toast to the offset for the new insets instead of keeping the one from
    /// when it was shown. Does nothing while the toast is hidden or being dismissed.
    private func updateRestingOffsetIfPresented() {
        guard isPresented, let toastView = activityPresenterViewController.view else { return }
        let transform = restingTransform(for: activityPresenterPosition)
        guard toastView.transform != transform else { return }
        toastView.transform = transform
    }

    private func animateActivityViewDismissal(
        _ view: UIView,
        generation: Int
    ) {
        isPresented = false
        view.isUserInteractionEnabled = true
        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseIn]
        ) { [weak self] in
            guard let self = self else { return }
            switch self.activityPresenterPosition {
            case .top:
                view.transform = CGAffineTransform(
                    translationX: 0,
                    y: -(view.frame.height + verticalPadding)
                )
            case .bottom:
                view.transform = CGAffineTransform(
                    translationX: 0,
                    y: view.frame.height + verticalPadding
                )
            case .center:
                break
            }
        } completion: { [weak self] _ in
            guard let self,
                  self.dismissalGeneration == generation else {
                return
            }
            self.pendingDismissWorkItem = nil
            self.removeSuccessTouchRecognizer()
            self.containerView.removeFromSuperview()
            self.activityPresenterViewProvider.updateState(.dismiss)
            self.currentState = .dismiss
            self.hostView = nil
        }
    }
}

/// Holds the toast view in the host view, full size and transparent. It passes touches through
/// wherever the toast view doesn't take them, as the toast view alone did before, and reports
/// safe area changes of the host view (which it fills).
private final class ActivityPresenterContainerView: UIView {
    var onSafeAreaInsetsChange: (() -> Void)?

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onSafeAreaInsetsChange?()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view === self ? nil : view
    }
}

extension ActivityPresenterRuuviLogo: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldReceive _: UITouch
    ) -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.dismissSuccessToastImmediately()
        }
        return false
    }
}
