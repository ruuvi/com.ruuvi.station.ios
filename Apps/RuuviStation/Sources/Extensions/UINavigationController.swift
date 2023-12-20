import UIKit

extension UINavigationController {
    override open func viewWillLayoutSubviews() {
        navigationBar.topItem?.backButtonDisplayMode = .minimal
    }

    func makeTransparent() {
        navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationBar.shadowImage = UIImage()
        navigationBar.isTranslucent = true
    }

    func resetStyleToDefault() {
        navigationBar.setBackgroundImage(nil, for: .default)
        navigationBar.shadowImage = nil
    }

    /// Given the kind of a (UIViewController subclass),
    /// removes any matching instances from self's
    /// viewControllers array.
    func removeAnyViewControllers(ofKind kind: AnyClass) {
        viewControllers = viewControllers.filter { !$0.isKind(of: kind) }
    }

    /// Given the kind of a (UIViewController subclass),
    /// returns true if self's viewControllers array contains at
    /// least one matching instance.
    func containsViewController(ofKind kind: AnyClass) -> Bool {
        viewControllers.contains(where: { $0.isKind(of: kind) })
    }
}
