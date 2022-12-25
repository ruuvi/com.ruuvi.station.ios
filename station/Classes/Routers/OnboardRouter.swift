import UIKit
import RuuviOnboard
import RuuviUser

protocol OnboardRouterDelegate: AnyObject {
    func onboardRouterDidFinish(_ router: OnboardRouter)
    func onboardRouterDidFinish(_ router: OnboardRouter,
                                module: SignInModuleInput,
                                showDashboard: Bool)
    func onboardRouterDidShowSignIn(_ router: OnboardRouter, output: SignInModuleOutput)
}

final class OnboardRouter {
    let r = AppAssembly.shared.assembler.resolver
    weak var delegate: OnboardRouterDelegate?
    var viewController: UIViewController {
        return self.onboard.viewController
    }

    // modules
    private var onboard: RuuviOnboard {
        if let onboard = self.weakOnboard {
            return onboard
        } else {
            let ruuviUser = r.resolve(RuuviUser.self)!
            let onboard = RuuviOnboardPages(ruuviUser: ruuviUser)
            onboard.router = self
            onboard.output = self
            self.weakOnboard = onboard
            return onboard
        }
    }
    private weak var weakOnboard: RuuviOnboard?
}

extension OnboardRouter: RuuviOnboardOutput {
    func ruuviOnboardDidFinish(_ ruuviOnboard: RuuviOnboard) {
        delegate?.onboardRouterDidFinish(self)
    }

    func ruuviOnboardDidShowSignIn(_ ruuviOnboard: RuuviOnboard) {
        delegate?.onboardRouterDidShowSignIn(self, output: self)
    }
}

extension OnboardRouter: SignInModuleOutput {
    func signIn(module: SignInModuleInput, didCloseSignInWithoutAttempt sender: Any?) {
        delegate?.onboardRouterDidFinish(self, module: module, showDashboard: false)
    }

    func signIn(module: SignInModuleInput, didSelectUseWithoutAccount sender: Any?) {
        delegate?.onboardRouterDidFinish(self, module: module, showDashboard: true)
    }

    func signIn(module: SignInModuleInput, didSuccessfulyLogin sender: Any?) {
        delegate?.onboardRouterDidFinish(self, module: module, showDashboard: true)
    }
}
