import RuuviOnboard
import RuuviUser
import UIKit

protocol OnboardRouterDelegate: AnyObject {
    func onboardRouterDidFinish(_ router: OnboardRouter)
    func onboardRouterDidFinish(
        _ router: OnboardRouter,
        module: SignInBenefitsModuleInput,
        showDashboard: Bool
    )
    func onboardRouterDidShowSignIn(
        _ router: OnboardRouter,
        output: SignInBenefitsModuleOutput
    )
}

final class OnboardRouter {
    let r = AppAssembly.shared.assembler.resolver
    weak var delegate: OnboardRouterDelegate?
    var viewController: UIViewController {
        onboard.viewController
    }

    // modules
    private var onboard: RuuviOnboard {
        if let onboard = weakOnboard {
            return onboard
        } else {
            let ruuviUser = r.resolve(RuuviUser.self)!
            let onboard = RuuviOnboardPages(ruuviUser: ruuviUser)
            onboard.router = self
            onboard.output = self
            weakOnboard = onboard
            return onboard
        }
    }

    private weak var weakOnboard: RuuviOnboard?
}

extension OnboardRouter: RuuviOnboardOutput {
    func ruuviOnboardDidFinish(_: RuuviOnboard) {
        delegate?.onboardRouterDidFinish(self)
    }

    func ruuviOnboardDidShowSignIn(_: RuuviOnboard) {
        delegate?.onboardRouterDidShowSignIn(self, output: self)
    }
}

extension OnboardRouter: SignInBenefitsModuleOutput {
    func signIn(module: SignInBenefitsModuleInput, didCloseSignInWithoutAttempt _: Any?) {
        delegate?.onboardRouterDidFinish(self, module: module, showDashboard: false)
    }

    func signIn(module: SignInBenefitsModuleInput, didSelectUseWithoutAccount _: Any?) {
        delegate?.onboardRouterDidFinish(self, module: module, showDashboard: true)
    }

    func signIn(module: SignInBenefitsModuleInput, didSuccessfulyLogin _: Any?) {
        delegate?.onboardRouterDidFinish(self, module: module, showDashboard: true)
    }
}
