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
            if let viewModel = dashboardViewController.viewModels.first(where: { viewModel in
                viewModel.mac.value?.value == macId || viewModel.luid.value?.value == macId
            }) {
                dashboardViewController.output.viewDidTriggerOpenSensorCardFromWidget(for: viewModel)
                settings.setCardToOpenFromWidget(for: nil)
            }
        }
    }

}
