import UIKit

extension UIView {
    convenience init(
        color: UIColor? = .clear,
        cornerRadius: CGFloat = 0,
        borderWidth: CGFloat = 0,
        borderColor: UIColor = .clear
    ) {
        self.init()
        layer.cornerRadius = cornerRadius
        layer.borderWidth = borderWidth
        layer.borderColor = borderColor.cgColor
        backgroundColor = color
        clipsToBounds = true
    }
}
