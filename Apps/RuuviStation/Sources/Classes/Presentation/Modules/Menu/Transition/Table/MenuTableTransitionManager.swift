import UIKit

class MenuTableTransitionManager: NSObject {
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

    /// The menu width in a container (the window) of `size`: three quarters of its shorter side, at
    /// most 260pt. That is 260pt on every iPhone (except 240pt at 320pt wide) and on full-screen
    /// iPad. The presentation controller asks again on every layout, so the menu follows a window
    /// that is resized while it is open.
    static func menuWidth(in size: CGSize) -> CGFloat {
        min(round(min(size.width, size.height) * 0.75), 260)
    }
}
