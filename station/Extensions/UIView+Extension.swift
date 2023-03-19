import UIKit

extension UIView {
    func disable(_ disable: Bool) {
        self.alpha = disable ? 0.4 : 1
        self.isUserInteractionEnabled = !disable
    }
}
