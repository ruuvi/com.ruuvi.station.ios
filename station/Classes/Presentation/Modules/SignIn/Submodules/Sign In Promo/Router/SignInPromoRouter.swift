import LightRoute
import UIKit

class SignInPromoRouter: SignInPromoRouterInput {
    weak var transitionHandler: UIViewController!

    func dismiss(completion: (() -> Void)?) {
        transitionHandler.dismiss(animated: true, completion: completion)
    }

    func popViewController(animated: Bool) {
        transitionHandler.navigationController?.popViewController(animated: animated)
    }
}
