import LightRoute
import UIKit

class SignInBenefitsRouter: SignInBenefitsRouterInput {
    weak var transitionHandler: UIViewController!

    func dismiss(completion: (() -> Void)?) {
        transitionHandler.dismiss(animated: true, completion: completion)
    }

    func openSignIn(output: SignInModuleOutput) {
        let factory: SignInModuleFactory = SignInModuleFactoryImpl()
        let module = factory.create()

        transitionHandler
            .navigationController?
            .pushViewController(
                module,
                animated: true
            )

        if let presenter = module.output as? SignInModuleInput {
            presenter.configure(with: .enterEmail, output: output)
        }
    }
}
