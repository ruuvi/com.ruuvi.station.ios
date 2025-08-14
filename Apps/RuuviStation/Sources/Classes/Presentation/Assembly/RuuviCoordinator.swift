import UIKit

class RuuviCoordinator: NSObject {
    private(set) weak var baseViewController: UIViewController!

    init(baseViewController: UIViewController) {
        super.init()
        self.baseViewController = baseViewController
    }

    public func start() {}
    public func stop() {}
}
