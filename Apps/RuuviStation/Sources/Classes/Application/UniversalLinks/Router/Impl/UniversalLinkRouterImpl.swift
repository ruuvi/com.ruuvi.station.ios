import LightRoute
import UIKit
import RuuviLocal

class UniversalLinkRouterImpl: UniversalLinkRouter {
    func openSignInVerify(with code: String, from transitionHandler: TransitionHandler) {
        let factory: SignInModuleFactory = SignInModuleFactoryImpl()
        let module = factory.create()
        let navigationController = UINavigationController(
            rootViewController: module)
        if let viewController = transitionHandler as? UIViewController {
            viewController.present(navigationController, animated: true)
        }

        if let presenter = module.output as? SignInModuleInput {
            presenter.configure(with: .enterVerificationCode(code), output: nil)
        }
    }

    func openSensorCard(
        with macId: String,
        settings: RuuviLocalSettings,
        from transitionHandler: TransitionHandler
    ) {
        guard let rootViewController = transitionHandler as? UIViewController,
              let dashboardViewController = resolveDashboardViewController(from: rootViewController),
              let snapshot = dashboardViewController.snapshots.first(
                  where: { snapshot in
                      snapshot.identifierData.mac?.value == macId ||
                      snapshot.identifierData.luid?.value == macId ||
                      snapshot.id == macId
                  }) else {
            return
        }

        let openCard = {
            dashboardViewController.output
                .viewDidTriggerOpenSensorCardFromWidget(for: snapshot)
            settings.setCardToOpenFromWidget(for: nil)
        }

        if let navigationController = dashboardViewController.navigationController,
           navigationController.topViewController !== dashboardViewController {
            navigationController.popToViewController(dashboardViewController, animated: false)
        }

        if dashboardViewController.presentedViewController != nil {
            dashboardViewController.dismiss(animated: false) {
                openCard()
            }
        } else {
            openCard()
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func resolveDashboardViewController(
        from root: UIViewController
    ) -> DashboardViewController? {
        var stack: [UIViewController] = [root]
        var visited = Set<ObjectIdentifier>()

        while let current = stack.popLast() {
            let identifier = ObjectIdentifier(current)
            guard visited.insert(identifier).inserted else {
                continue
            }

            if let dashboard = current as? DashboardViewController {
                return dashboard
            }

            if let navigationController = current as? UINavigationController {
                stack.append(contentsOf: navigationController.viewControllers)
            }

            if let tabController = current as? UITabBarController {
                if let selected = tabController.selectedViewController {
                    stack.append(selected)
                }
                if let viewControllers = tabController.viewControllers {
                    stack.append(contentsOf: viewControllers)
                }
            }

            if let presented = current.presentedViewController {
                stack.append(presented)
            }

            if let presenting = current.presentingViewController {
                stack.append(presenting)
            }

            if let navigationController = current.navigationController {
                stack.append(navigationController)
            }

            if let parent = current.parent {
                stack.append(parent)
            }

            stack.append(contentsOf: current.children)
        }

        return nil
    }

}
