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

    private func discoverRouter() -> RuuviDiscoverRouter {
        if let discoverRouter = weakDiscoverRouter {
            return discoverRouter
        } else {
            let discoverRouter = RuuviDiscoverRouter()
            discoverRouter.delegate = self
            self.weakDiscoverRouter = discoverRouter
            return discoverRouter
        }
    }
    private weak var weakDiscoverRouter: RuuviDiscoverRouter?
}

extension AppRouter: OnboardRouterDelegate {
    func onboardRouterDidFinish(_ router: OnboardRouter) {
//        settings.welcomeShown = true
        let discover = self.discoverRouter().viewController
        navigationController.pushViewController(discover, animated: true)
    }
}

extension AppRouter: RuuviDiscoverRouterDelegate {
    func discoverRouterWantsClose(_ router: RuuviDiscoverRouter) {
        let storyboard = UIStoryboard(name: "Cards", bundle: .main)
        let cards = storyboard.instantiateInitialViewController()!
        navigationController.pushViewController(cards, animated: true)
    }
}
