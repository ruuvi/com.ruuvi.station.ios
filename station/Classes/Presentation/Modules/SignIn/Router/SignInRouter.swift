import LightRoute
import UIKit

class SignInRouter: SignInRouterInput {
    weak var transitionHandler: UIViewController!

    func dismiss(completion: (() -> Void)?) {
        transitionHandler.dismiss(animated: true, completion: completion)
    }

    func popViewController(animated: Bool) {
        transitionHandler.navigationController?.popViewController(animated: animated)
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
