import UIKit

extension UIImageView {
    convenience init(image: UIImage? = nil,
                     backgroundColor: UIColor = .clear,
                     contentMode: ContentMode = .scaleAspectFill,
                     cornerRadius: CGFloat = 0)
    {
        self.init()
        self.image = image
        self.backgroundColor = backgroundColor
        self.contentMode = contentMode
        layer.cornerRadius = cornerRadius
        clipsToBounds = true
        isUserInteractionEnabled = true
    }
}
