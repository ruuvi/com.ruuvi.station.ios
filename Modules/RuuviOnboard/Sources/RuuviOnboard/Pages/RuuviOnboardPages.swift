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
            weakView = view
            return view
        }
    }

    private let ruuviUser: RuuviUser

    public init(ruuviUser: RuuviUser) {
        self.ruuviUser = ruuviUser
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
}
