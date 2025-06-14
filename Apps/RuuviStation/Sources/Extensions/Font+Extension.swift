import SwiftUI
import UIKit

// MARK: - SwiftUI Font convenience accessors
public extension Font {

    // MARK: – Convenience
    /// Matches `UIFont.systemFontSize` (≈ 17 pt) for call-sites that omit `size:`
    static let systemFontSize: CGFloat = UIFont.systemFontSize

    // ---------- Montserrat ----------
    enum MontserratStyle: String {
        case bold = "Bold"
        case regular = "Regular"
        case extraBold = "ExtraBold"
    }

    static func Montserrat(
        _ style: MontserratStyle = .regular,
        size: CGFloat = Font.systemFontSize
    ) -> Font {
        .custom("Montserrat-\(style.rawValue)", size: size.adjustedSize())
    }

    // ---------- Mul(i/ish) ----------
    enum MuliStyle: String {
        case bold = "Bold"
        case regular = "Regular"
        case semiBoldItalic = "SemiBoldItalic"
        case extraBold = "ExtraBold"
    }

    static func Muli(
        _ style: MuliStyle = .regular,
        size: CGFloat = Font.systemFontSize
    ) -> Font {
        let prefix = (style == .semiBoldItalic || style == .extraBold) ? "Mulish" : "Muli"
        return .custom("\(prefix)-\(style.rawValue)", size: size.adjustedSize())
    }

    // ---------- Oswald ----------
    enum OswaldStyle: String {
        case bold       = "Bold"
        case regular    = "Regular"
        case light      = "Light"
        case extraLight = "ExtraLight"
    }

    static func Oswald(
        _ style: OswaldStyle = .extraLight,
        size: CGFloat = Font.systemFontSize
    ) -> Font {
        .custom("Oswald-\(style.rawValue)", size: size.adjustedSize())
    }
}
