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

    func openEmailConfirmation(output: SignInModuleOutput) {
        let restorationId = "SignInViewController"
        let factory = StoryboardFactory(storyboardName: "SignIn", bundle: .main, restorationId: restorationId)
        try! transitionHandler
            .forStoryboard(factory: factory, to: SignInModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(with: .enterVerificationCode, output: output)
            })
    }
}
