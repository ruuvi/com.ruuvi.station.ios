import LightRoute
import UIKit

class SensorForceClaimRouter: SensorForceClaimRouterInput {
    weak var transitionHandler: UIViewController?

    func dismiss() {
        try? transitionHandler?.closeCurrentModule().perform()
    }
}
