import UIKit

extension CALayer {

    @IBInspectable var borderColorIB: UIColor? {
        get {
            if let borderColorCG = borderColor {
                return UIColor(cgColor: borderColorCG)
            } else {
                return nil
            }
        }
        set {
            borderColor = newValue?.cgColor
        }
    }

    @IBInspectable var shadowColorIB: UIColor? {
        get {
            if let shadowColorCG = shadowColor {
                return UIColor(cgColor: shadowColorCG)
            } else {
                return nil
            }
        }
        set {
            shadowColor = newValue?.cgColor
        }
    }
}
