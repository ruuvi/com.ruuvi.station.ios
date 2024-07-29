import LightRoute
import UIKit
import RuuviLocal

protocol UniversalLinkRouter {
    func openSignInVerify(with code: String, from transitionHandler: TransitionHandler)
    func openSensorCard(
        with macId: String,
        settings: RuuviLocalSettings,
        from transitionHandler: TransitionHandler
    )
}
