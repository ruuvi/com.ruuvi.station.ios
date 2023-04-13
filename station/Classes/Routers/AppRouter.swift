import UIKit
import RuuviLocal
import LightRoute
import RuuviUser

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
                let controller = dashboardViewController()
                rootViewController = controller
            } else {
                AppUtility.lockOrientation(.portrait)
                rootViewController = self.onboardRouter().viewController
            }
            let navigationController = UINavigationController(rootViewController: rootViewController)
            navigationController.navigationBar.tintColor = .clear
            self.weakNavigationController = navigationController
            return navigationController
        }
    }

    private weak var weakNavigationController: UINavigationController?
    private weak var weakDashboardController: UIViewController?

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

    private func discoverRouter() -> DiscoverRouter {
        if let discoverRouter = weakDiscoverRouter {
            return discoverRouter
        } else {
            let discoverRouter = DiscoverRouter()
            discoverRouter.delegate = self
            self.weakDiscoverRouter = discoverRouter
            return discoverRouter
        }
    }
    private weak var weakDiscoverRouter: DiscoverRouter?

    /// Return dashboard view controller
    private func dashboardViewController() -> UIViewController {
        let factory: DashboardModuleFactory = DashboardModuleFactoryImpl()
        let module = factory.create()
        weakDashboardController = module
        return module
    }

    /// Prepare root view controller When app launched from widget tapped.
    func prepareRootViewControllerWidgets() {
        let rootViewController: UIViewController
        if settings.welcomeShown {
            if let weakDashboardController = weakDashboardController {
                rootViewController = weakDashboardController
            } else {
                let controller = dashboardViewController()
                rootViewController = controller
            }
        } else {
            rootViewController = self.onboardRouter().viewController
        }
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.navigationBar.tintColor = .clear
        self.weakNavigationController = navigationController
    }
}

extension AppRouter: OnboardRouterDelegate {
    func onboardRouterDidShowSignIn(_ router: OnboardRouter,
                                    output: SignInPromoModuleOutput) {
        let factory: SignInPromoModuleFactory = SignInPromoModuleFactoryImpl()
        let module = factory.create()

        let navigationController = UINavigationController(
            rootViewController: module)
        viewController.present(navigationController, animated: true)

        if let presenter = module.output as? SignInPromoModuleInput {
            presenter.configure(output: output)
        }
    }

    func onboardRouterDidFinish(_ router: OnboardRouter) {
        presentDashboard()
    }

    func onboardRouterDidFinish(_ router: OnboardRouter,
                                module: SignInPromoModuleInput,
                                showDashboard: Bool) {
        module.dismiss(completion: { [weak self] in
            if showDashboard {
                self?.presentDashboard()
            }
        })
    }

    private func presentDashboard() {
        settings.welcomeShown = true
        AppUtility.lockOrientation(.all)
        let controller = dashboardViewController()
        navigationController.setNavigationBarHidden(false, animated: false)
        navigationController.pushViewController(controller, animated: true)
    }
}

extension AppRouter: DiscoverRouterDelegate {
    func discoverRouterWantsClose(_ router: DiscoverRouter) {
        if let weakDashboardController = weakDashboardController {
            navigationController.pushViewController(weakDashboardController,
                                                    animated: true)
        } else {
            let controller = dashboardViewController()
            navigationController.pushViewController(controller, animated: true)
        }
    }
}
