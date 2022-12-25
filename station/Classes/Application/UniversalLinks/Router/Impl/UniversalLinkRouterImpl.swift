import UIKit
import LightRoute

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
}
