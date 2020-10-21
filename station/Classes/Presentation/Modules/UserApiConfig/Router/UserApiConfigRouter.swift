import UIKit

class UserApiConfigRouter: UserApiConfigRouterInput {
    weak var transitionHandler: UIViewController!

    func dismiss(completion: (() -> Void)?) {
        transitionHandler.dismiss(animated: true, completion: completion)
    }

    func showAlert(_ viewModel: UserApiConfigAlertViewModel) {
        let alertController = UIAlertController(title: viewModel.title,
                                      message: viewModel.message,
                                      preferredStyle: viewModel.style)
        viewModel.actions.forEach({ alertController.addAction($0) })
        transitionHandler.present(alertController,
                                  animated: true,
                                  completion: nil)
    }
}
