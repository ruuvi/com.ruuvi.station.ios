import UIKit

extension UIView {
    convenience init(color: UIColor? = .clear,
                     cornerRadius: CGFloat = 0,
                     borderWidth: CGFloat = 0,
                     borderColor: UIColor = .clear) {
        self.init()
        self.layer.cornerRadius = cornerRadius
        self.layer.borderWidth = borderWidth
        self.layer.borderColor = borderColor.cgColor
        self.backgroundColor = color
        clipsToBounds = true
    }
}
