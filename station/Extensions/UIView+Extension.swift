import UIKit

extension UIView {
    func disable(_ disable: Bool) {
        alpha = disable ? 0.4 : 1
        isUserInteractionEnabled = !disable
    }
}

extension UIView {
    func fadeIn(animated: Bool = true) {
        guard alpha == 0 else { return }
        if animated {
            UIView.animate(withDuration: 0.3,
                           delay: 0.0,
                           options: .curveLinear,
                           animations: { [weak self] in
                               self?.alpha = 1
                               self?.layoutIfNeeded()
                           })
        } else {
            alpha = 1
        }
    }

    func fadeOut(animated: Bool = true) {
        guard alpha == 1 else { return }
        if animated {
            UIView.animate(withDuration: 0.3,
                           delay: 0.0,
                           options: .curveLinear,
                           animations: { [weak self] in
                               self?.alpha = 0
                               self?.layoutIfNeeded()
                           })
        } else {
            alpha = 0
        }
    }
}
