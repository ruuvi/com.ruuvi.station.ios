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
        if let dashboardViewController = transitionHandler as? DashboardViewController {
            if let snapshot = dashboardViewController.snapshots.first(
                where: { snapshot in
                    snapshot.identifierData.mac?.value == macId || snapshot.identifierData.luid?.value == macId
                }) {
                dashboardViewController.output
                    .viewDidTriggerOpenSensorCardFromWidget(
                        for: snapshot
                    )
                settings
                    .setCardToOpenFromWidget(
                        for: nil
                    )
            }
        }
    }

}
