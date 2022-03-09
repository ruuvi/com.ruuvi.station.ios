import UIKit
extension UINavigationController {
  open override func viewWillLayoutSubviews() {
      if #available(iOS 14.0, *) {
          navigationBar.topItem?.backButtonDisplayMode = .minimal
      } else {
          navigationBar.topItem?.title = " "
      }
  }
}
