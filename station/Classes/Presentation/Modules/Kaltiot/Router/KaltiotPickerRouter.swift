import UIKit

class KaltiotPickerRouter: KaltiotPickerRouterInput {
    weak var transitionHandler: UIViewController!

    func popViewController(animated: Bool) {
        transitionHandler.navigationController?.popViewController(animated: animated)
    }
}
