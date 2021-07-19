import UIKit
import RuuviLocal

final class AppRouter {
    var viewController: UIViewController {
        return self.navigationController
    }

    var settings: RuuviLocalSettings!

    // navigation controller
    private var navigationController: UINavigationController {
        if let navigationController = self.weakNavigationController {
            return navigationController
        } else {
            let rootViewController: UIViewController
            if settings.welcomeShown {
                let storyboard = UIStoryboard(name: "Cards", bundle: .main)
                rootViewController = storyboard.instantiateInitialViewController()!
            } else {
                rootViewController = self.onboardRouter().viewController
            }
            let navigationController = UINavigationController(rootViewController: rootViewController)
            navigationController.setNavigationBarHidden(true, animated: false)
            self.weakNavigationController = navigationController
            return navigationController
        }
    }

    private weak var weakNavigationController: UINavigationController?

    // routers
    private func onboardRouter() -> OnboardRouter {
        if let onboardRouter = self.weakOnboardRouter {
            return onboardRouter
        } else {
            let onboardRouter = OnboardRouter()
            onboardRouter.delegate = self
            self.weakOnboardRouter = onboardRouter
            return onboardRouter
        }
    }
    private weak var weakOnboardRouter: OnboardRouter?
}

extension AppRouter: OnboardRouterDelegate {
    func onboardRouterDidFinish(_ router: OnboardRouter) {
        settings.welcomeShown = true
        openDiscover()
    }

    private func openDiscover() {
        let welcomeRouter = WelcomeRouter()
        welcomeRouter.transitionHandler = navigationController.topViewController
        welcomeRouter.openDiscover()
    }
}
