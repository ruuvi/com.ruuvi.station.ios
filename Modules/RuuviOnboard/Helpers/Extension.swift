import Foundation
import UIKit

public extension UIAlertController {
    func setMessageAlignment(_ alignment: NSTextAlignment) {
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
        paragraphStyle?.alignment = alignment

        let messageText = NSMutableAttributedString(
            string: self.message ?? "",
            attributes: [
                NSAttributedString.Key.paragraphStyle: paragraphStyle,
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13),
                NSAttributedString.Key.foregroundColor: UIColor.label
            ]
        )
        self.setValue(messageText, forKey: "attributedMessage")
    }
}
