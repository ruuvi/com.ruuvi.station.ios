import UIKit

class MenuTableTransitionManager: NSObject {
    var menuWidth: CGFloat = min(round(min(appScreenRect.width, appScreenRect.height) * 0.75), 260)
    var container: UIViewController
    var menu: UIViewController
    var isInteractive: Bool = false
    var presentDirection: UIRectEdge = .left

    static var appScreenRect: CGRect {
        let appWindowRect = UIWindow.key?.bounds ?? UIWindow().bounds
        return appWindowRect
    }

    init(container: UIViewController, menu: UIViewController) {
        self.container = container
        self.menu = menu
    }
}
