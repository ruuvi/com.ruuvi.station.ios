import RuuviUser
import UIKit

public final class RuuviOnboardPages: RuuviOnboard {
    public weak var output: RuuviOnboardOutput?
    public var router: AnyObject?

    public var viewController: UIViewController {
        if let view = weakView {
            return view
        } else {
            let view = RuuviOnboardViewController()
            view.output = self
            view.ruuviUser = ruuviUser
            view.tosAccepted = tosAccepted
            view.analyticsConsentGiven = analyticsConsentGiven
            weakView = view
            return view
        }
    }

    private let ruuviUser: RuuviUser
    private var tosAccepted: Bool
    private var analyticsConsentGiven: Bool

    public init(
        ruuviUser: RuuviUser,
        tosAccepted: Bool,
        analyticsConsentGiven: Bool
    ) {
        self.ruuviUser = ruuviUser
        self.tosAccepted = tosAccepted
        self.analyticsConsentGiven = analyticsConsentGiven
    }

    private weak var weakView: UIViewController?
}

extension RuuviOnboardPages: RuuviOnboardViewControllerOutput {
    func ruuviOnboardPages(
        _: RuuviOnboardViewController,
        didFinish _: Any?
    ) {
        output?.ruuviOnboardDidFinish(self)
    }

    func ruuviOnboardCloudSignIn(
        _: RuuviOnboardViewController,
        didPresentSignIn _: Any?
    ) {
        output?.ruuviOnboardDidShowSignIn(self)
    }

    func ruuviOnboardAnalytics(
        _ viewController: RuuviOnboardViewController,
        didProvideAnalyticsConsent isConsentGiven: Bool,
        sender: Any?
    ) {
        output?.ruuviOnboardDidProvideAnalyticsConsent(
            self,
            consentGiven: isConsentGiven
        )
    }
}
