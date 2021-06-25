import UIKit
import LightRoute

protocol UniversalLinkRouter {
    func openSignInVerify(with code: String, from transitionHandler: TransitionHandler)
}
