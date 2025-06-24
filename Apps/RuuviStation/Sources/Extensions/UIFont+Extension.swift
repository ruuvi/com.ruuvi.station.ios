import UIKit

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

    // MARK: - TIGHT FONT VARIANTS

    static func MontserratTight(
        _ type: MontserratStyles = .regular,
        size: CGFloat = UIFont.systemFontSize
    ) -> UIFont {
        return Montserrat(type, size: size).tightFont()
    }

    static func MuliTight(
        _ type: MuliStyles = .regular,
        size: CGFloat = UIFont.systemFontSize
    ) -> UIFont {
        return Muli(type, size: size).tightFont()
    }

    static func OswaldTight(
        _ type: OswaldStyles = .extraLight,
        size: CGFloat = UIFont.systemFontSize
    ) -> UIFont {
        return Oswald(type, size: size).tightFont()
    }

    // MARK: - ORIGINAL FUNCTIONS

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

    // MARK: - TIGHT FONT UTILITIES

    /// Returns font metrics for precise typography
    var tightMetrics: FontTightMetrics {
        return FontTightMetrics(font: self)
    }

    /// Returns a font sized to use exact typographic space
    func tightFont() -> UIFont {
        let exactHeight = capHeight + abs(descender)
        let ratio = exactHeight / lineHeight
        return withSize(pointSize * ratio)
    }

    /// Returns exact height without font padding
    var exactHeight: CGFloat {
        return capHeight + abs(descender)
    }

    /// Returns the padding that fonts add above cap height
    var topPadding: CGFloat {
        return ascender - capHeight
    }

    /// Returns the padding that fonts add below baseline
    var bottomPadding: CGFloat {
        return abs(descender)
    }
}

// MARK: - Font Metrics Helper

public struct FontTightMetrics {
    let font: UIFont
    let exactHeight: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let capHeight: CGFloat
    let baseline: CGFloat

    init(font: UIFont) {
        self.font = font
        self.exactHeight = font.capHeight + abs(font.descender)
        self.topPadding = font.ascender - font.capHeight
        self.bottomPadding = abs(font.descender)
        self.capHeight = font.capHeight
        self.baseline = font.descender
    }

    /// Returns offset to align this font's cap height with another font's cap height
    func capHeightOffset(relativeTo otherFont: UIFont) -> CGFloat {
        let otherMetrics = FontTightMetrics(font: otherFont)
        return otherMetrics.topPadding - self.topPadding
    }

    /// Returns offset to align this font's baseline with another font's baseline
    func baselineOffset(relativeTo otherFont: UIFont) -> CGFloat {
        let otherMetrics = FontTightMetrics(font: otherFont)
        return otherMetrics.baseline - self.baseline
    }
}

extension CGFloat {
    func adjustedSize() -> CGFloat {
        GlobalHelpers.isDeviceTablet() ? self + 2 : self
    }
}
