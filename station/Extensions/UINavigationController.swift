import UIKit
extension UINavigationController {
  open override func viewWillLayoutSubviews() {
      navigationBar.topItem?.backButtonDisplayMode = .minimal
  }
}
