import UIKit

class RUColor: UIColor {
    open class override var secondarySystemGroupedBackground: UIColor {
        if #available(iOS 13.0, *) {
            return super.secondarySystemGroupedBackground
        } else {
            return UIColor.white
        }
    }

    open class override var systemGray4: UIColor {
        if #available(iOS 13.0, *) {
            return super.systemGray4
        } else {
            return UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1.0)
        }
    }

    open class override var systemGray3: UIColor {
        if #available(iOS 13.0, *) {
            return super.systemGray3
        } else {
            return UIColor(red: 0.78, green: 0.78, blue: 0.8, alpha: 1.0)
        }
    }

    open class override var label: UIColor {
        if #available(iOS 13.0, *) {
            return super.label
        } else {
            return UIColor.black
        }
    }

    open class override var secondaryLabel: UIColor {
        if #available(iOS 13.0, *) {
            return super.secondaryLabel
        } else {
            return UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.6)
        }
    }

    open class override var tertiaryLabel: UIColor {
        if #available(iOS 13.0, *) {
            return super.tertiaryLabel
        } else {
            return UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 0.3)
        }
    }
}
