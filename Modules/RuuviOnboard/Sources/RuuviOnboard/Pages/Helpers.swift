import Foundation
import UIKit

// MARK: - Alert controller extension

public extension UIAlertController {
    func setMessageAlignment(_ alignment: NSTextAlignment) {
        guard let paragraphStyle = NSParagraphStyle.default.mutableCopy() as? NSMutableParagraphStyle else {
            return
        }
        paragraphStyle.alignment = alignment

        let messageText = NSMutableAttributedString(
            string: message ?? "",
            attributes: [
                NSAttributedString.Key.paragraphStyle: paragraphStyle,
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 15),
                NSAttributedString.Key.foregroundColor: UIColor.label,
            ]
        )
        setValue(messageText, forKey: "attributedMessage")
    }
}

extension UIDevice {
    static func isTablet() -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
}
