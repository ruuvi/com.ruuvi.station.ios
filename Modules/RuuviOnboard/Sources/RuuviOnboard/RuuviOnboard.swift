import UIKit

public protocol RuuviOnboard: AnyObject {
    var viewController: UIViewController { get }
    var router: AnyObject? { get set }
}

public protocol RuuviOnboardOutput: AnyObject {
    func ruuviOnboardDidFinish(_ ruuviOnboard: RuuviOnboard)
    func ruuviOnboardDidShowSignIn(_ ruuviOnboard: RuuviOnboard)
    func ruuviOnboardDidProvideAnalyticsConsent(
        _ ruuviOnboard: RuuviOnboard,
        consentGiven: Bool
    )
}
