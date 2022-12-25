import UIKit
import RuuviUser

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
            self.weakView = view
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
    func ruuviOnboardPages(_ viewController: RuuviOnboardViewController,
                           didFinish sender: Any?) {
        output?.ruuviOnboardDidFinish(self)
    }

    func ruuviOnboardCloudSignIn(_ viewController: RuuviOnboardViewController,
                                 didPresentSignIn sender: Any?) {
        output?.ruuviOnboardDidShowSignIn(self)
    }
}
