import LightRoute
import UIKit

protocol UniversalLinkRouter {
    func openSignInVerify(with code: String, from transitionHandler: TransitionHandler)
}
