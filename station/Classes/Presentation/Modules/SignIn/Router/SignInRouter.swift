import LightRoute
import UIKit

class SignInRouter: SignInRouterInput {
    weak var transitionHandler: UIViewController!

    func dismiss(completion: (() -> Void)?) {
        transitionHandler.dismiss(animated: true, completion: completion)
    }

    func popViewController(animated: Bool, completion: (() -> Void)?) {
        if let navigationController =
            transitionHandler.navigationController,
            navigationController.viewControllers.count > 1 {
            // There is at least one view controller that can be popped
            navigationController.popViewController(animated: animated)
        } else {
            // There are no view controllers that can be popped
            transitionHandler.dismiss(animated: animated, completion: completion)
        }
    }

    func openSignInPromoViewController(output: SignInPromoModuleOutput) {
        let factory: SignInPromoModuleFactory = SignInPromoModuleFactoryImpl()
        let module = factory.create()

        transitionHandler
            .navigationController?
            .pushViewController(
                module,
                animated: true
            )
        if let presenter = module.output as? SignInPromoModuleInput {
            presenter.configure(output: output)
        }
    }
}
