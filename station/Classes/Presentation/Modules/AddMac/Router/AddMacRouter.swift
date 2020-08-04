import UIKit

class AddMacRouter: AddMacRouterInput {
    weak var transitionHandler: UIViewController!

    func dismiss(completion: (() -> Void)?) {
        transitionHandler.dismiss(animated: true, completion: completion)
    }
}
