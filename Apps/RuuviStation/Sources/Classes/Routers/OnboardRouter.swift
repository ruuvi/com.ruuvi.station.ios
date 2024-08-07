import RuuviLocal
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
    func ruuviOnboardDidProvideAnalyticsConsent(
        _ router: OnboardRouter,
        consentGiven: Bool
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
            let settings = r.resolve(RuuviLocalSettings.self)!
            let onboard = RuuviOnboardPages(
                ruuviUser: ruuviUser,
                tosAccepted: settings.tosAccepted,
                analyticsConsentGiven: settings.analyticsConsentGiven
            )
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

    func ruuviOnboardDidProvideAnalyticsConsent(
        _ ruuviOnboard: RuuviOnboard,
        consentGiven: Bool
    ) {
        delegate?.ruuviOnboardDidProvideAnalyticsConsent(
            self,
            consentGiven: consentGiven
        )
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
