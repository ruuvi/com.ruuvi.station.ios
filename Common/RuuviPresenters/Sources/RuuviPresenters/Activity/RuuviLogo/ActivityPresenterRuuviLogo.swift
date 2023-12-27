import UIKit

public final class ActivityPresenterRuuviLogo {
    // Minimum duration to keep the activity indicator on the screen
    private let minAnimationTime: CFTimeInterval = 1.5
    // Animation duration for presenting and dismissing the activity indicator.
    private let animationDuration: CGFloat = 0.5
    // Vertical(top/bottom) padding for activity indicator depending on position.
    private let verticalPadding: CGFloat = 8

    private let activityPresenterViewProvider: ActivityPresenterViewProvider
    private let activityPresenterViewController: UIViewController
    private let stateHolder = ActivityPresenterStateHolder()

    private var activityPresenterPosition: ActivityPresenterPosition = .bottom
    private var startTime: CFTimeInterval?

    public init() {
        activityPresenterViewProvider = ActivityPresenterViewProvider(stateHolder: stateHolder)
        activityPresenterViewController = activityPresenterViewProvider.makeViewController()
        activityPresenterViewController.view.backgroundColor = .clear
    }
}

extension ActivityPresenterRuuviLogo: ActivityPresenter {
    public func show(
        with state: ActivityPresenterState,
        atPosition position: ActivityPresenterPosition
    ) {
        activityPresenterPosition = position
        activityPresenterViewProvider.updatePosition(position)
        startTime = CFAbsoluteTimeGetCurrent()

        guard let topController = RuuviPresenterHelper.topViewController(),
              let toastView = activityPresenterViewController.view else {
            return
        }

        topController.view.addSubview(toastView)
        setupConstraints(for: toastView, in: topController)
        animateActivityViewPresentation(toastView, atPosition: position)

        activityPresenterViewProvider.updateState(state)
    }

    public func update(with state: ActivityPresenterState) {
        startTime = CFAbsoluteTimeGetCurrent()
        activityPresenterViewProvider.updateState(state)
    }

    public func dismiss(immediately: Bool) {
        let executionTime = CFAbsoluteTimeGetCurrent() - (startTime ?? 0)
        let additionalWaitTime = immediately ? 0 : max(minAnimationTime - executionTime, 0)

        guard let toastView = activityPresenterViewController.view else {
            return
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + additionalWaitTime
        ) { [weak self] in
            self?.animateActivityViewDismissal(toastView)
        }
    }
}

extension ActivityPresenterRuuviLogo {
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
            options: [.curveEaseOut]
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

    private func animateActivityViewDismissal(_ view: UIView) {
        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            options: [.curveEaseIn]
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
            view.removeFromSuperview()
            self?.activityPresenterViewProvider.updateState(.dismiss)
        }
    }

    private func safeAreaInsets() -> UIEdgeInsets {
        RuuviPresenterHelper.topViewController()?.view.safeAreaInsets ?? .zero
    }
}
