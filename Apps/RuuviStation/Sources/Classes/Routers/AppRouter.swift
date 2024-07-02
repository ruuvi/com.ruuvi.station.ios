import LightRoute
import RuuviAnalytics
import RuuviLocal
import RuuviOntology
import RuuviUser
import UIKit

final class AppRouter {
    var viewController: UIViewController {
        navigationController
    }

    var settings: RuuviLocalSettings!
    var ruuviAnalytics: RuuviAnalytics!

    // navigation controller
    private var navigationController: UINavigationController {
        if let navigationController = weakNavigationController {
            return navigationController
        } else {
            let rootViewController: UIViewController
            if settings.welcomeShown && settings.tosAccepted && settings.analyticsConsentGiven {
                let controller = dashboardViewController()
                rootViewController = controller
            } else {
                AppUtility.lockOrientation(.portrait)
                rootViewController = onboardRouter().viewController
            }
            let navigationController = UINavigationController(rootViewController: rootViewController)
            navigationController.navigationBar.tintColor = .clear
            weakNavigationController = navigationController
            return navigationController
        }
    }

    private weak var weakNavigationController: UINavigationController?
    private weak var weakDashboardController: UIViewController?

    // routers
    private func onboardRouter() -> OnboardRouter {
        if let onboardRouter = weakOnboardRouter {
            return onboardRouter
        } else {
            let onboardRouter = OnboardRouter()
            onboardRouter.delegate = self
            weakOnboardRouter = onboardRouter
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
            weakDiscoverRouter = discoverRouter
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
        if settings.welcomeShown && settings.tosAccepted {
            if let weakDashboardController {
                rootViewController = weakDashboardController
            } else {
                let controller = dashboardViewController()
                rootViewController = controller
            }
        } else {
            rootViewController = onboardRouter().viewController
        }
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.navigationBar.tintColor = .clear
        weakNavigationController = navigationController
    }
}

extension AppRouter: OnboardRouterDelegate {
    func onboardRouterDidShowSignIn(
        _: OnboardRouter,
        output: SignInBenefitsModuleOutput
    ) {
        let factory: SignInBenefitsModuleFactory = SignInPromoModuleFactoryImpl()
        let module = factory.create()

        let navigationController = UINavigationController(
            rootViewController: module)
        viewController.present(navigationController, animated: true)

        if let presenter = module.output as? SignInBenefitsModuleInput {
            presenter.configure(output: output)
        }
    }

    func onboardRouterDidFinish(_: OnboardRouter) {
        presentDashboard()
    }

    func onboardRouterDidFinish(
        _: OnboardRouter,
        module: SignInBenefitsModuleInput,
        showDashboard: Bool
    ) {
        module.dismiss(completion: { [weak self] in
            if showDashboard {
                self?.presentDashboard()
            }
        })
    }

    func ruuviOnboardDidProvideAnalyticsConsent(
        _ router: OnboardRouter,
        consentGiven: Bool
    ) {
        ruuviAnalytics.setConsent(
            allowed: consentGiven
        )
    }

    private func presentDashboard() {
        settings.welcomeShown = true
        settings.tosAccepted = true
        settings.analyticsConsentGiven = true
        AppUtility.lockOrientation(.all)
        let controller = dashboardViewController()
        navigationController.setNavigationBarHidden(false, animated: false)
        navigationController.setViewControllers([controller], animated: true)
    }
}

extension AppRouter: DiscoverRouterDelegate {
    func discoverRouterWantsClose(_: DiscoverRouter) {
        if let weakDashboardController {
            navigationController.pushViewController(
                weakDashboardController,
                animated: true
            )
        } else {
            let controller = dashboardViewController()
            navigationController.setViewControllers([controller], animated: true)
        }
    }

    func discoverRouterWantsCloseWithRuuviTagNavigation(
        _: DiscoverRouter,
        ruuviTag _: RuuviTagSensor
    ) {
        // No op.
    }
}
