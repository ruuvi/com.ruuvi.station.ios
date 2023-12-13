import UIKit

extension CALayer {
    @IBInspectable var borderColorIB: UIColor? {
        get {
            if let borderColorCG = borderColor {
                UIColor(cgColor: borderColorCG)
            } else {
                nil
            }
        }
        set {
            borderColor = newValue?.cgColor
        }
    }

    @IBInspectable var shadowColorIB: UIColor? {
        get {
            if let shadowColorCG = shadowColor {
                UIColor(cgColor: shadowColorCG)
            } else {
                nil
            }
        }
        set {
            shadowColor = newValue?.cgColor
        }
    }
}
