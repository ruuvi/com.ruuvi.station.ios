import UIKit

extension UIButton {
    func underline() {
        guard let text = self.titleLabel?.text,
              let titleColor = self.titleColor(for: .normal) else { return }
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
        self.setAttributedTitle(attributedString, for: .normal)
    }
}
