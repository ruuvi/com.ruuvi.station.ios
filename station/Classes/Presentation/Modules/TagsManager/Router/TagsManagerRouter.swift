import UIKit

class TagsManagerRouter: TagsManagerRouterInput {
    weak var transitionHandler: UIViewController!

    func dismiss(completion: (() -> Void)?) {
        transitionHandler.dismiss(animated: true, completion: completion)
    }
}
