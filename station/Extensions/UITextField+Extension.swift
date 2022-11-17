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
