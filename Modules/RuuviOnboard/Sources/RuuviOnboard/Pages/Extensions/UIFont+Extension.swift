import UIKit

extension UIFont {
    enum MontserratStyles: String {
        case bold = "Bold"
        case regular = "Regular"
        case extraBold = "ExtraBold"
    }

    enum MuliStyles: String {
        case bold = "Bold"
        case regular = "Regular"
        case semiBoldItalic = "SemiBoldItalic"
    }

    enum OswaldStyles: String {
        case bold = "Bold"
        case extraLight = "ExtraLight"
    }

    // MARK: - FUNCTIONS
    static func Montserrat(_ type: MontserratStyles = .regular,
                           size: CGFloat = UIFont.systemFontSize) -> UIFont {
        return UIFont(name: "Montserrat-\(type.rawValue)",
                      size: size.adjustedSize()) ??
        UIFont.systemFont(ofSize: size.adjustedSize())
    }

    static func Muli(_ type: MuliStyles = .regular,
                     size: CGFloat = UIFont.systemFontSize) -> UIFont {
        let prefix = type == .semiBoldItalic ? "Mulish" : "Muli"
        return UIFont(name: "\(prefix)-\(type.rawValue)",
                      size: size.adjustedSize()) ??
        UIFont.systemFont(ofSize: size.adjustedSize())
    }

    static func Oswald(_ type: OswaldStyles = .extraLight,
                       size: CGFloat = UIFont.systemFontSize) -> UIFont {
        return UIFont(name: "Oswald-\(type.rawValue)",
                      size: size.adjustedSize()) ??
        UIFont.systemFont(ofSize: size.adjustedSize(),
                          weight: .ultraLight)
    }
}

extension CGFloat {
    func adjustedSize() -> CGFloat {
        return UIDevice.current.userInterfaceIdiom == .pad ? self + 4 : self
    }
}
