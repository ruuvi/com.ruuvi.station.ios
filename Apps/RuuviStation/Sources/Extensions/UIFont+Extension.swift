import UIKit
import SwiftUI

// MARK: - UIKit
public extension UIFont {
    enum MontserratStyles: String {
        case bold = "Bold"
        case regular = "Regular"
        case extraBold = "ExtraBold"
    }

    enum MuliStyles: String {
        case bold = "Bold"
        case regular = "Regular"
        case semiBoldItalic = "SemiBoldItalic"
        case extraBold = "ExtraBold"
    }

    enum OswaldStyles: String {
        case bold = "Bold"
        case regular = "Regular"
        case light = "Light"
        case extraLight = "ExtraLight"
    }

    // MARK: - FUNCTIONS

    static func Montserrat(
        _ type: MontserratStyles = .regular,
        size: CGFloat = UIFont.systemFontSize
    ) -> UIFont {
        UIFont(
            name: "Montserrat-\(type.rawValue)",
            size: size.adjustedSize()
        ) ??
            UIFont.systemFont(ofSize: size.adjustedSize())
    }

    static func Muli(
        _ type: MuliStyles = .regular,
        size: CGFloat = UIFont.systemFontSize
    ) -> UIFont {
        let prefix = (type == .semiBoldItalic || type == .extraBold) ? "Mulish" : "Muli"
        return UIFont(
            name: "\(prefix)-\(type.rawValue)",
            size: size.adjustedSize()
        ) ??
            UIFont.systemFont(ofSize: size.adjustedSize())
    }

    static func Oswald(
        _ type: OswaldStyles = .extraLight,
        size: CGFloat = UIFont.systemFontSize
    ) -> UIFont {
        UIFont(
            name: "Oswald-\(type.rawValue)",
            size: size.adjustedSize()
        ) ??
            UIFont.systemFont(
                ofSize: size.adjustedSize(),
                weight: .ultraLight
            )
    }
}

// MARK: - SwiftUI
extension Font {
    static func montserrat(
        _ type: UIFont.MontserratStyles = .regular,
        size: CGFloat = UIFont.systemFontSize
    ) -> Font {
        Font(
            UIFont.Montserrat(
                type,
                size: size
            )
        )
    }

    static func muli(
        _ type: UIFont.MuliStyles = .regular,
        size: CGFloat = UIFont.systemFontSize
    ) -> Font {
        Font(
            UIFont.Muli(
                type,
                size: size
            )
        )
    }

    static func oswald(
        _ type: UIFont.OswaldStyles = .extraLight,
        size: CGFloat = UIFont.systemFontSize
    ) -> Font {
        Font(
            UIFont.Oswald(
                type,
                size: size
            )
        )
    }
}

// MARK: - Helpers
extension CGFloat {
    func adjustedSize() -> CGFloat {
        GlobalHelpers.isDeviceTablet() ? self + 4 : self
    }
}
