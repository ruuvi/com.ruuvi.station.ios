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
        if toastView.superview !== topController.view {
            toastView.removeFromSuperview()
            topController.view.addSubview(toastView)
            setupConstraints(for: toastView, in: topController)
        } else {
            topController.view.bringSubviewToFront(toastView)
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
            if activityPresenterViewController.view.superview != nil,
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
        activityPresenterViewController.view.removeFromSuperview()
        activityPresenterViewProvider.updateState(.dismiss)
        currentState = .dismiss
        hostView = nil
    }

    private func setupConstraints(
        for view: UIView,
        in viewController: UIViewController
    ) {
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(
                equalTo: viewController.view.leadingAnchor
            ),
            view.trailingAnchor.constraint(
                equalTo: viewController.view.trailingAnchor
            ),
            view.topAnchor.constraint(
                equalTo: viewController.view.topAnchor
            ),
            view.bottomAnchor.constraint(
                equalTo: viewController.view.bottomAnchor
            ),
        ])
    }

    private func animateActivityViewPresentation(
        _ view: UIView,
        atPosition position: ActivityPresenterPosition
    ) {
        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseOut]
        ) { [weak self] in
            guard let self = self else { return }
            switch position {
            case .top:
                view.transform = CGAffineTransform(
                    translationX: 0,
                    y: self.safeAreaInsets().top + self.verticalPadding
                )
            case .bottom:
                view.transform = CGAffineTransform(
                    translationX: 0,
                    y: -(self.safeAreaInsets().bottom + self.verticalPadding)
                )
            case .center:
                view.transform = .identity
            }
        }
    }

    private func animateActivityViewDismissal(
        _ view: UIView,
        generation: Int
    ) {
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
            view.removeFromSuperview()
            self.activityPresenterViewProvider.updateState(.dismiss)
            self.currentState = .dismiss
            self.hostView = nil
        }
    }

    private func safeAreaInsets() -> UIEdgeInsets {
        RuuviPresenterHelper.topViewController()?.view.safeAreaInsets ?? .zero
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
