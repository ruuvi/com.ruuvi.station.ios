import UIKit

extension UIApplication {
    func topViewController(_ base: UIViewController? = nil) -> UIViewController? {
        let base = base ?? keyWindow?.rootViewController
        if let top = (base as? UINavigationController)?.topViewController {
            return topViewController(top)
        }
        if let selected = (base as? UITabBarController)?.selectedViewController {
            return topViewController(selected)
        }
        if let presented = base?.presentedViewController, !presented.isBeingDismissed {
            return topViewController(presented)
        }
        return base
    }
}
