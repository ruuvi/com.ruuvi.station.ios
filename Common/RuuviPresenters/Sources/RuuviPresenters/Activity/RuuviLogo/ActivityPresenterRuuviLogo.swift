import UIKit

public final class ActivityPresenterRuuviLogo: ActivityPresenter {
    let minAnimationTime: CFTimeInterval = 1.0
    var startTime: CFTimeInterval?
    let window = UIWindow(frame: UIScreen.main.bounds)
    let activityPresenterViewProvider: ActivityPresenterViewProvider
    let activityPresenterViewController: UIViewController
    let stateHolder = ActivityPresenterStateHolder()

    weak var appWindow: UIWindow?

    public init() {
        activityPresenterViewProvider = ActivityPresenterViewProvider(stateHolder: stateHolder)
        activityPresenterViewController = activityPresenterViewProvider.makeViewController()
        activityPresenterViewController.view.backgroundColor = .clear
        window.windowLevel = .normal
        activityPresenterViewController.view.translatesAutoresizingMaskIntoConstraints = false
        window.rootViewController = activityPresenterViewController
    }
}

extension ActivityPresenterRuuviLogo {
    public func setPosition(_ position: ActivityPresenterPosition) {
        activityPresenterViewProvider.updatePosition(position)
    }

    public func show(with state: ActivityPresenterState) {
        startTime = CFAbsoluteTimeGetCurrent()
        appWindow = UIWindow.key
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        activityPresenterViewProvider.updateState(state)
    }

    public func update(with state: ActivityPresenterState) {
        activityPresenterViewProvider.updateState(state)
    }

    public func dismiss(immediately: Bool) {
        let executionTime = CFAbsoluteTimeGetCurrent() - (startTime ?? 0)
        let additionalWaitTime = immediately ? 0 :
            executionTime < minAnimationTime ? (minAnimationTime - executionTime) : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + additionalWaitTime) { [weak self] in
            self?.activityPresenterViewProvider.updateState(.dismiss)
            self?.appWindow?.makeKeyAndVisible()
            self?.appWindow = nil
            self?.window.isHidden = true
        }
    }
}
