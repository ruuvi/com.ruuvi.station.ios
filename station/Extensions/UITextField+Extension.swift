import UIKit

extension UITextField {
    func addNumericAccessory() {
        let numberToolbar = UIToolbar()
        numberToolbar.barStyle = UIBarStyle.default
        var accessories: [UIBarButtonItem] = []
        accessories.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil))
        accessories.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil))
        let minusButton = UIBarButtonItem(
            title: "－",
            style: UIBarButtonItem.Style.plain,
            target: self,
            action: #selector(handleMinusTap)
        )
        minusButton.tintColor = .label
        accessories.append(minusButton)
        numberToolbar.items = accessories
        numberToolbar.sizeToFit()
        inputAccessoryView = numberToolbar
    }

    @objc func handleMinusTap() {
        guard let currentText = text
        else {
            return
        }
        if currentText.hasPrefix("－") {
            let offsetIndex = currentText.index(currentText.startIndex, offsetBy: 1)
            let substring = currentText[offsetIndex...]
            text = String(substring)
        } else {
            text = "-" + currentText
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
        leftViewMode = .always
        layer.masksToBounds = true

        switch padding {
        case let .left(spacing):
            let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: spacing, height: frame.height))
            leftView = leftPaddingView
            leftViewMode = .always

        case let .right(spacing):
            let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: spacing, height: frame.height))
            rightView = rightPaddingView
            rightViewMode = .always

        case let .equalSpacing(spacing):
            let equalPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: spacing, height: frame.height))
            // left
            leftView = equalPaddingView
            leftViewMode = .always
            // right
            rightView = equalPaddingView
            rightViewMode = .always
        }
    }

    func setPlaceHolderColor(color: UIColor?) {
        guard let placeholder,
              let color
        else {
            return
        }

        attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [NSAttributedString.Key.foregroundColor: color]
        )
    }
}
