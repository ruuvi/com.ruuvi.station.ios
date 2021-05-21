import UIKit
import LightRoute

class UniversalLinkRouterImpl: UniversalLinkRouter {
    func openSignInVerify(with code: String, from transitionHandler: TransitionHandler) {
        let factory = StoryboardFactory(storyboardName: "SignIn")
        try! transitionHandler
            .forStoryboard(factory: factory, to: SignInModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(with: .enterVerificationCode(code), output: nil)
        })
    }
}
