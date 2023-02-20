import UIKit

extension UINavigationController {
    open override func viewWillLayoutSubviews() {
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
}
