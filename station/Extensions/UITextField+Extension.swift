import UIKit

extension UITextField {

    func addNumericAccessory() {
        let numberToolbar = UIToolbar()
        numberToolbar.barStyle = UIBarStyle.default
        var accessories: [UIBarButtonItem] = []
        accessories.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil))
        accessories.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil))
        let minusButton = UIBarButtonItem(title: "－",
                                          style: UIBarButtonItem.Style.plain,
                                          target: self,
                                          action: #selector(handleMinusTap))
        minusButton.tintColor = .label
        accessories.append(minusButton)
        numberToolbar.items = accessories
        numberToolbar.sizeToFit()
        inputAccessoryView = numberToolbar
    }

    @objc func handleMinusTap() {
        guard let currentText = self.text else {
            return
        }
        if currentText.hasPrefix("－") {
            let offsetIndex = currentText.index(currentText.startIndex, offsetBy: 1)
            let substring = currentText[offsetIndex...]
            self.text = String(substring)
        } else {
            self.text = "-" + currentText
        }
    }

}

extension UITextField {

    enum PaddingSpace {
        case left(CGFloat)
        case right(CGFloat)
        case equalSpacing(CGFloat)
    }

    func addPadding(padding: PaddingSpace) {

        self.leftViewMode = .always
        self.layer.masksToBounds = true

        switch padding {
        case .left(let spacing):
            let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: spacing, height: self.frame.height))
            self.leftView = leftPaddingView
            self.leftViewMode = .always

        case .right(let spacing):
            let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: spacing, height: self.frame.height))
            self.rightView = rightPaddingView
            self.rightViewMode = .always

        case .equalSpacing(let spacing):
            let equalPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: spacing, height: self.frame.height))
            // left
            self.leftView = equalPaddingView
            self.leftViewMode = .always
            // right
            self.rightView = equalPaddingView
            self.rightViewMode = .always
        }
    }

    func setPlaceHolderColor(color: UIColor?) {
        guard let placeholder = placeholder,
        let color = color else {
            return
        }

        self.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [NSAttributedString.Key.foregroundColor: color]
        )
    }
}
