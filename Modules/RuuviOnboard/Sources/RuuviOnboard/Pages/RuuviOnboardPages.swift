import UIKit

public final class RuuviOnboardPages: RuuviOnboard {
    public weak var output: RuuviOnboardOutput?
    public var router: AnyObject?
    public var viewController: UIViewController {
        if let view = weakView {
            return view
        } else {
            let view = RuuviOnboardPagesViewController()
            view.output = self
            self.weakView = view
            return view
        }
    }

    public init() {}

    private weak var weakView: UIViewController?
}

extension RuuviOnboardPages: RuuviOnboardPagesViewControllerOutput {
    func ruuviOnboardPages(_ viewController: RuuviOnboardPagesViewController, didFinish sender: Any?) {
        output?.ruuviOnboardDidFinish(self)
    }
}
