import UIKit

extension UIButton {
    func underline() {
        guard let text = titleLabel?.text,
              let titleColor = titleColor(for: .normal) else { return }
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(NSAttributedString.Key.underlineColor,
                                      value: titleColor,
                                      range: NSRange(location: 0,
                                                     length: text.count))
        attributedString.addAttribute(NSAttributedString.Key.foregroundColor,
                                      value: titleColor,
                                      range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(NSAttributedString.Key.underlineStyle,
                                      value: NSUnderlineStyle.single.rawValue,
                                      range: NSRange(location: 0, length: text.count))
        setAttributedTitle(attributedString, for: .normal)
    }
}
