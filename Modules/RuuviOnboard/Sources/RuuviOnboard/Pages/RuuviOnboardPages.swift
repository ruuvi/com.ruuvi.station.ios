import UIKit
import RuuviUser

public final class RuuviOnboardPages: RuuviOnboard {
    public weak var output: RuuviOnboardOutput?
    public var router: AnyObject?
    public var viewController: UIViewController {
        if let view = weakView {
            return view
        } else {
            let view = RuuviOnboardPagesViewController()
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

extension RuuviOnboardPages: RuuviOnboardPagesViewControllerOutput {
    func ruuviOnboardCloudSignIn(_ viewController: RuuviOnboardPagesViewController, didPresentSignIn sender: Any?) {
        output?.ruuviOnboardDidShowSignIn(self)
    }

    func ruuviOnboardPages(_ viewController: RuuviOnboardPagesViewController, didFinish sender: Any?) {
        output?.ruuviOnboardDidFinish(self)
    }
}
