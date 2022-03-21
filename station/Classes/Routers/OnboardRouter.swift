import UIKit
import RuuviOnboard

protocol OnboardRouterDelegate: AnyObject {
    func onboardRouterDidFinish(_ router: OnboardRouter)
}

final class OnboardRouter {
    weak var delegate: OnboardRouterDelegate?
    var viewController: UIViewController {
        return self.onboard.viewController
    }

    // modules
    private var onboard: RuuviOnboard {
        if let onboard = self.weakOnboard {
            return onboard
        } else {
            let onboard = RuuviOnboardPages()
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
}
