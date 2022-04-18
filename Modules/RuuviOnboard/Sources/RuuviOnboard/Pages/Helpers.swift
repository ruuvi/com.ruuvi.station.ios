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

// MARK: - Model Identifier

public extension UIViewController {
    func isiPhoneSE() -> Bool {
        return modelIdentifier() == "iPhone8,4"
            || modelIdentifier() == "iPhone12,8"
            || modelIdentifier() == "iPhone14,6"
    }

    fileprivate func modelIdentifier() -> String {
        if let simulatorModelIdentifier = ProcessInfo()
            .environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModelIdentifier
        }
        var sysinfo = utsname()
        uname(&sysinfo) // ignore return value
        return String(bytes: Data(bytes: &sysinfo.machine,
                                  count: Int(_SYS_NAMELEN)),
                      encoding: .ascii)!.trimmingCharacters(in: .controlCharacters)
    }
}
