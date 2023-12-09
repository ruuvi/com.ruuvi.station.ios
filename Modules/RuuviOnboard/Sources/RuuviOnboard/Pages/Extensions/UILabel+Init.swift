import UIKit

extension UILabel {
    convenience init(text: String,
                     textColor: UIColor = .label,
                     font: UIFont = .Muli(.regular, size: 16),
                     numberOfLines: Int = 0,
                     alignment: NSTextAlignment = .left)
    {
        self.init()
        self.text = text
        self.textColor = textColor
        self.font = font
        self.numberOfLines = numberOfLines
        textAlignment = alignment
    }
}
