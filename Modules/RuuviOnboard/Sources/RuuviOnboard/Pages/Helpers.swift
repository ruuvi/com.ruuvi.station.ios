import Foundation
import UIKit

// MARK: - Alert controller extension
public extension UIAlertController {
    func setMessageAlignment(_ alignment: NSTextAlignment) {
        let paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle
        paragraphStyle?.alignment = alignment

        let messageText = NSMutableAttributedString(
            string: self.message ?? "",
            attributes: [
                NSAttributedString.Key.paragraphStyle: paragraphStyle,
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15),
                NSAttributedString.Key.foregroundColor: UIColor.label
            ]
        )
        self.setValue(messageText, forKey: "attributedMessage")
    }
}

extension UIDevice {
    static func isTablet() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
}
