// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
    import AppKit
    import CoreText
#elseif os(iOS)
    import UIKit
    import CoreText
#elseif os(tvOS) || os(watchOS)
    import UIKit
    import CoreText
#endif
#if canImport(SwiftUI)
    import SwiftUI
#endif

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Font Registration

private final class FontRegistration {
    static let shared = FontRegistration()
    private var registeredFonts: Set<String> = []

    private init() {
        registerFonts()
    }

    private func registerFonts() {
        let fontNames = [
            "Mulish-Regular",
            "Mulish-Bold",
            "Mulish-ExtraBold",
            "Mulish-SemiBoldItalic",
            "Montserrat-Regular",
            "Montserrat-Bold",
            "Montserrat-ExtraBold",
            "Oswald-Regular",
            "Oswald-Light",
            "Oswald-ExtraLight",
            "Oswald-Bold"
        ]

        for fontName in fontNames {
            registerFont(named: fontName)
        }
    }

    private func registerFont(named fontName: String) {
        if UIFont(name: fontName, size: 12.0) != nil {
            registeredFonts.insert(fontName)
            return
        }

        guard !registeredFonts.contains(fontName) else { return }

        let bundle = BundleToken.bundle

        let possibleURLs = [
            bundle.url(forResource: fontName, withExtension: "ttf", subdirectory: "Fonts"),
            bundle.url(forResource: fontName, withExtension: "otf", subdirectory: "Fonts"),
            bundle.url(forResource: fontName, withExtension: "ttf", subdirectory: "Resources/Fonts"),
            bundle.url(forResource: fontName, withExtension: "otf", subdirectory: "Resources/Fonts"),
            bundle.url(forResource: fontName, withExtension: "ttf"),
            bundle.url(forResource: fontName, withExtension: "otf"),
        ]

        guard let fontURL = possibleURLs.first(where: { $0 != nil }) else {
            return
        }

        guard let fontURL = fontURL,
              let fontData = NSData(contentsOf: fontURL),
              let provider = CGDataProvider(data: fontData),
              let font = CGFont(provider) else {
            return
        }

        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterGraphicsFont(font, &error)

        if success {
            registeredFonts.insert(fontName)
        }
    }
}

// MARK: - Font Assets

public struct FontAsset {
    public fileprivate(set) var name: String
    public fileprivate(set) var family: String
    public fileprivate(set) var style: String

    #if os(macOS)
    public typealias Font = NSFont
    #elseif os(iOS) || os(tvOS) || os(watchOS)
    public typealias Font = UIFont
    #endif

    public func font(size: CGFloat) -> Font {
        // Ensure fonts are registered
        _ = FontRegistration.shared

        var fontSize = size
        if UIDevice.current.userInterfaceIdiom == .pad {
            fontSize += 2
        }

        guard let font = Font(name: name, size: fontSize) else {
            return Font.systemFont(ofSize: fontSize)
        }
        return font
    }

    #if os(iOS) || os(tvOS) || os(watchOS)
    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    public func scaledFont(for textStyle: UIFont.TextStyle, size: CGFloat? = nil) -> Font {
        // Ensure fonts are registered
        _ = FontRegistration.shared

        let baseSize = size ?? UIFont.preferredFont(forTextStyle: textStyle).pointSize

        guard let customFont = Font(name: name, size: baseSize) else {
            return Font.preferredFont(forTextStyle: textStyle)
        }

        // Use UIFontMetrics to scale the font
        let fontMetrics = UIFontMetrics(forTextStyle: textStyle)
        return fontMetrics.scaledFont(for: customFont)
    }
    #endif

    #if canImport(SwiftUI)
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
    public func swiftUIFont(size: CGFloat) -> SwiftUI.Font {
        return .custom(name, size: size)
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    public func swiftUIFont(size: CGFloat, relativeTo textStyle: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
        return .custom(name, size: size, relativeTo: textStyle)
    }
    #endif
}

// MARK: - Font Catalog

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
public enum RuuviFonts {
    public enum Mulish {
        public static let regular = FontAsset(
            name: "Mulish-Regular",
            family: "Mulish",
            style: "Regular"
        )
        public static let bold = FontAsset(
            name: "Mulish-Bold",
            family: "Mulish",
            style: "Bold"
        )
        public static let extraBold = FontAsset(
            name: "Mulish-ExtraBold",
            family: "Mulish",
            style: "ExtraBold"
        )
        public static let semiBoldItalic = FontAsset(
            name: "Mulish-SemiBoldItalic",
            family: "Mulish",
            style: "SemiBoldItalic"
        )
    }

    public enum Montserrat {
        public static let regular = FontAsset(
            name: "Montserrat-Regular",
            family: "Montserrat",
            style: "Regular"
        )
        public static let bold = FontAsset(
            name: "Montserrat-Bold",
            family: "Montserrat",
            style: "Bold"
        )
        public static let extraBold = FontAsset(
            name: "Montserrat-ExtraBold",
            family: "Montserrat",
            style: "ExtraBold"
        )
    }

    public enum Oswald {
        public static let extraLight = FontAsset(
            name: "Oswald-ExtraLight",
            family: "Oswald",
            style: "ExtraLight"
        )
        public static let light = FontAsset(
            name: "Oswald-Light",
            family: "Oswald",
            style: "Light"
        )
        public static let regular = FontAsset(
            name: "Oswald-Regular",
            family: "Oswald",
            style: "Regular"
        )
        public static let bold = FontAsset(
            name: "Oswald-Bold",
            family: "Oswald",
            style: "Bold"
        )
    }

    // MARK: - Type-Safe Weight Enums
    public enum MulishWeight: String, CaseIterable {
        case regular = "Regular"
        case bold = "Bold"
        case extraBold = "ExtraBold"
        case semiBoldItalic = "SemiBoldItalic"

        var fontAsset: FontAsset {
            switch self {
            case .regular: return Mulish.regular
            case .bold: return Mulish.bold
            case .extraBold: return Mulish.extraBold
            case .semiBoldItalic: return Mulish.semiBoldItalic
            }
        }
    }

    public enum MontserratWeight: String, CaseIterable {
        case regular = "Regular"
        case bold = "Bold"
        case extraBold = "ExtraBold"

        var fontAsset: FontAsset {
            switch self {
            case .regular: return Montserrat.regular
            case .bold: return Montserrat.bold
            case .extraBold: return Montserrat.extraBold
            }
        }
    }

    public enum OswaldWeight: String, CaseIterable {
        case extraLight = "ExtraLight"
        case light = "Light"
        case regular = "Regular"
        case bold = "Bold"

        var fontAsset: FontAsset {
            switch self {
            case .extraLight: return Oswald.extraLight
            case .light: return Oswald.light
            case .regular: return Oswald.regular
            case .bold: return Oswald.bold
            }
        }
    }

    // MARK: - Typography Styles (Mulish-based)
    public enum Typography {
        // Headlines - Using Mulish ExtraBold/Bold for impact
        public enum Headlines {
            public static func large(size: CGFloat = 32) -> FontAsset { Mulish.extraBold }
            public static func medium(size: CGFloat = 22) -> FontAsset { Mulish.bold }
            public static func small(size: CGFloat = 16) -> FontAsset { Mulish.bold }
            public static func tiny(size: CGFloat = 12) -> FontAsset { Mulish.bold }
        }

        // Body Text - Using Mulish Regular for readability
        public enum Body {
            public static func large(size: CGFloat = 18) -> FontAsset { Mulish.regular }
            public static func medium(size: CGFloat = 16) -> FontAsset { Mulish.regular }
            public static func small(size: CGFloat = 14) -> FontAsset { Mulish.regular }
        }

        // Caption Text - Using Mulish Regular for UI elements
        public enum Caption {
            public static func large(size: CGFloat = 12) -> FontAsset { Mulish.regular }
            public static func small(size: CGFloat = 10) -> FontAsset { Mulish.regular }
        }

        // Buttons - Using Mulish Bold for UI controls
        public enum Buttons {
            public static func large(size: CGFloat = 18) -> FontAsset { Mulish.bold }
            public static func medium(size: CGFloat = 16) -> FontAsset { Mulish.bold }
            public static func small(size: CGFloat = 14) -> FontAsset { Mulish.bold }
        }
    }

    // MARK: - Dynamic Type Support (Mulish Only)
    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.15, *)
    public enum DynamicType {
        // Large Titles - Extra Bold for maximum impact
        case largeTitle(FontAsset = Mulish.extraBold)

        // Titles - Bold hierarchy
        case title1(FontAsset = Mulish.extraBold)
        case title2(FontAsset = Mulish.bold)
        case title3(FontAsset = Mulish.bold)

        // Headlines - Bold for emphasis
        case headline(FontAsset = Mulish.bold)
        case subheadline(FontAsset = Mulish.regular)

        // Body Text - Regular for readability
        case body(FontAsset = Mulish.regular)
        case callout(FontAsset = Mulish.bold)

        // Small Text - Regular weight
        case footnote(FontAsset = Mulish.regular)
        case caption1(FontAsset = Mulish.regular)
        case caption2(FontAsset = Mulish.regular)

        public var fontAsset: FontAsset {
            switch self {
            case .largeTitle(let asset): return asset
            case .title1(let asset): return asset
            case .title2(let asset): return asset
            case .title3(let asset): return asset
            case .headline(let asset): return asset
            case .subheadline(let asset): return asset
            case .body(let asset): return asset
            case .callout(let asset): return asset
            case .footnote(let asset): return asset
            case .caption1(let asset): return asset
            case .caption2(let asset): return asset
            }
        }

        #if os(iOS) || os(tvOS) || os(watchOS)
        public var textStyle: UIFont.TextStyle {
            switch self {
            case .largeTitle: return .largeTitle
            case .title1: return .title1
            case .title2: return .title2
            case .title3: return .title3
            case .headline: return .headline
            case .subheadline: return .subheadline
            case .body: return .body
            case .callout: return .callout
            case .footnote: return .footnote
            case .caption1: return .caption1
            case .caption2: return .caption2
            }
        }

        @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
        public func scaledFont() -> UIFont {
            return fontAsset.scaledFont(for: textStyle)
        }
        #endif

        #if canImport(SwiftUI)
        @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
        public var swiftUITextStyle: SwiftUI.Font.TextStyle {
            switch self {
            case .largeTitle: return .largeTitle
            case .title1: return .title
            case .title2: return .title2
            case .title3: return .title3
            case .headline: return .headline
            case .subheadline: return .subheadline
            case .body: return .body
            case .callout: return .callout
            case .footnote: return .footnote
            case .caption1: return .caption
            case .caption2: return .caption2
            }
        }

        @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
        public func swiftUIFont() -> SwiftUI.Font {
            let baseSize = self.baseSize
            return fontAsset.swiftUIFont(size: baseSize, relativeTo: swiftUITextStyle)
        }
        #endif

        // Base sizes that match Apple's defaults
        private var baseSize: CGFloat {
            switch self {
            case .largeTitle: return 34
            case .title1: return 28
            case .title2: return 22
            case .title3: return 20
            case .headline: return 17
            case .subheadline: return 15
            case .body: return 17
            case .callout: return 16
            case .footnote: return 13
            case .caption1: return 12
            case .caption2: return 11
            }
        }
    }

    // MARK: - Type-Safe Font Selection Methods (Primary API)

    /// Get Mulish UIFont with specific weight and size
    #if os(iOS) || os(tvOS) || os(watchOS)
    public static func mulish(_ weight: MulishWeight, size: CGFloat) -> UIFont {
        return weight.fontAsset.font(size: size)
    }

    /// Get Montserrat UIFont with specific weight and size
    public static func montserrat(_ weight: MontserratWeight, size: CGFloat) -> UIFont {
        return weight.fontAsset.font(size: size)
    }

    /// Get Oswald UIFont with specific weight and size
    public static func oswald(_ weight: OswaldWeight, size: CGFloat) -> UIFont {
        return weight.fontAsset.font(size: size)
    }

    /// Get Mulish font with Dynamic Type scaling
    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    public static func mulish(_ weight: MulishWeight, size: CGFloat, for textStyle: UIFont.TextStyle) -> UIFont {
        return weight.fontAsset.scaledFont(for: textStyle, size: size)
    }

    /// Get Montserrat font with Dynamic Type scaling
    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    public static func montserrat(_ weight: MontserratWeight, size: CGFloat, for textStyle: UIFont.TextStyle) -> UIFont {
        return weight.fontAsset.scaledFont(for: textStyle, size: size)
    }

    /// Get Oswald font with Dynamic Type scaling
    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    public static func oswald(_ weight: OswaldWeight, size: CGFloat, for textStyle: UIFont.TextStyle) -> UIFont {
        return weight.fontAsset.scaledFont(for: textStyle, size: size)
    }
    #endif

    // MARK: - SwiftUI Font Selection Methods
    #if canImport(SwiftUI)
    /// Get Mulish SwiftUI font
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
    public static func mulishSwiftUI(_ weight: MulishWeight, size: CGFloat) -> SwiftUI.Font {
        return weight.fontAsset.swiftUIFont(size: size)
    }

    /// Get Montserrat SwiftUI font
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
    public static func montserratSwiftUI(_ weight: MontserratWeight, size: CGFloat) -> SwiftUI.Font {
        return weight.fontAsset.swiftUIFont(size: size)
    }

    /// Get Oswald SwiftUI font
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
    public static func oswaldSwiftUI(_ weight: OswaldWeight, size: CGFloat) -> SwiftUI.Font {
        return weight.fontAsset.swiftUIFont(size: size)
    }

    /// Get Mulish SwiftUI font with Dynamic Type
    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    public static func mulishSwiftUI(_ weight: MulishWeight, size: CGFloat, relativeTo textStyle: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
        return weight.fontAsset.swiftUIFont(size: size, relativeTo: textStyle)
    }

    /// Get Montserrat SwiftUI font with Dynamic Type
    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    public static func montserratSwiftUI(_ weight: MontserratWeight, size: CGFloat, relativeTo textStyle: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
        return weight.fontAsset.swiftUIFont(size: size, relativeTo: textStyle)
    }

    /// Get Oswald SwiftUI font with Dynamic Type
    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    public static func oswaldSwiftUI(_ weight: OswaldWeight, size: CGFloat, relativeTo textStyle: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
        return weight.fontAsset.swiftUIFont(size: size, relativeTo: textStyle)
    }
    #endif
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - UIFont Extensions

#if os(iOS) || os(tvOS) || os(watchOS)
@available(iOS 8.0, tvOS 9.0, watchOS 2.0, *)
public extension UIFont {
    convenience init?(asset: FontAsset, size: CGFloat) {
        self.init(name: asset.name, size: size)
    }

    // MARK: - Static Typography Styles
    static func ruuviHeadlineLarge() -> UIFont {
        return RuuviFonts.Typography.Headlines.large().font(size: 32)
    }

    static func ruuviHeadlineMedium() -> UIFont {
        return RuuviFonts.Typography.Headlines.medium().font(size: 22)
    }

    static func ruuviHeadlineSmall() -> UIFont {
        return RuuviFonts.Typography.Headlines.small().font(size: 16)
    }

    static func ruuviHeadlineTiny() -> UIFont {
        return RuuviFonts.Typography.Headlines.tiny().font(size: 12)
    }

    static func ruuviBodyLarge() -> UIFont {
        return RuuviFonts.Typography.Body.large().font(size: 18)
    }

    static func ruuviBodyMedium() -> UIFont {
        return RuuviFonts.Typography.Body.medium().font(size: 16)
    }

    static func ruuviBodySmall() -> UIFont {
        return RuuviFonts.Typography.Body.small().font(size: 14)
    }

    static func ruuviCaptionLarge() -> UIFont {
        return RuuviFonts.Typography.Caption.large().font(size: 12)
    }

    static func ruuviCaptionSmall() -> UIFont {
        return RuuviFonts.Typography.Caption.small().font(size: 10)
    }

    static func ruuviButtonLarge() -> UIFont {
        return RuuviFonts.Typography.Buttons.large().font(size: 18)
    }

    static func ruuviButtonMedium() -> UIFont {
        return RuuviFonts.Typography.Buttons.medium().font(size: 16)
    }

    static func ruuviButtonSmall() -> UIFont {
        return RuuviFonts.Typography.Buttons.small().font(size: 14)
    }

    // MARK: - Dynamic Type Support
    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    static func ruuviLargeTitle() -> UIFont {
        return RuuviFonts.DynamicType.largeTitle().scaledFont()
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    static func ruuviTitle1() -> UIFont {
        return RuuviFonts.DynamicType.title1().scaledFont()
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    static func ruuviTitle2() -> UIFont {
        return RuuviFonts.DynamicType.title2().scaledFont()
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    static func ruuviTitle3() -> UIFont {
        return RuuviFonts.DynamicType.title3().scaledFont()
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    static func ruuviHeadline() -> UIFont {
        return RuuviFonts.DynamicType.headline().scaledFont()
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    static func ruuviSubheadline() -> UIFont {
        return RuuviFonts.DynamicType.subheadline().scaledFont()
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    static func ruuviBody() -> UIFont {
        return RuuviFonts.DynamicType.body().scaledFont()
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    static func ruuviCallout() -> UIFont {
        return RuuviFonts.DynamicType.callout().scaledFont()
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    static func ruuviFootnote() -> UIFont {
        return RuuviFonts.DynamicType.footnote().scaledFont()
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    static func ruuviCaption1() -> UIFont {
        return RuuviFonts.DynamicType.caption1().scaledFont()
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    static func ruuviCaption2() -> UIFont {
        return RuuviFonts.DynamicType.caption2().scaledFont()
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    /// Get Mulish UIFont with specific weight and size
    static func mulish(_ weight: RuuviFonts.MulishWeight, size: CGFloat) -> UIFont {
        return weight.fontAsset.font(size: size)
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    /// Get Montserrat UIFont with specific weight and size
    static func montserrat(_ weight: RuuviFonts.MontserratWeight, size: CGFloat) -> UIFont {
        return weight.fontAsset.font(size: size)
    }

    @available(iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    /// Get Oswald UIFont with specific weight and size
    static func oswald(_ weight: RuuviFonts.OswaldWeight, size: CGFloat) -> UIFont {
        return weight.fontAsset.font(size: size)
    }
}
#endif

// MARK: - SwiftUI Font Extensions

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
public extension SwiftUI.Font {
    static func ruuvi(_ asset: FontAsset, size: CGFloat) -> SwiftUI.Font {
        return asset.swiftUIFont(size: size)
    }

    // MARK: - Static Typography Styles
    static func ruuviHeadlineLarge() -> SwiftUI.Font {
        return RuuviFonts.Typography.Headlines.large().swiftUIFont(size: 32)
    }

    static func ruuviHeadlineMedium() -> SwiftUI.Font {
        return RuuviFonts.Typography.Headlines.medium().swiftUIFont(size: 28)
    }

    static func ruuviHeadlineSmall() -> SwiftUI.Font {
        return RuuviFonts.Typography.Headlines.small().swiftUIFont(size: 24)
    }

    static func ruuviBodyLarge() -> SwiftUI.Font {
        return RuuviFonts.Typography.Body.large().swiftUIFont(size: 18)
    }

    static func ruuviBodyMedium() -> SwiftUI.Font {
        return RuuviFonts.Typography.Body.medium().swiftUIFont(size: 16)
    }

    static func ruuviBodySmall() -> SwiftUI.Font {
        return RuuviFonts.Typography.Body.small().swiftUIFont(size: 14)
    }

    static func ruuviCaptionLarge() -> SwiftUI.Font {
        return RuuviFonts.Typography.Caption.large().swiftUIFont(size: 12)
    }

    static func ruuviCaptionSmall() -> SwiftUI.Font {
        return RuuviFonts.Typography.Caption.small().swiftUIFont(size: 10)
    }

    static func ruuviButtonLarge() -> SwiftUI.Font {
        return RuuviFonts.Typography.Buttons.large().swiftUIFont(size: 18)
    }

    static func ruuviButtonMedium() -> SwiftUI.Font {
        return RuuviFonts.Typography.Buttons.medium().swiftUIFont(size: 16)
    }

    static func ruuviButtonSmall() -> SwiftUI.Font {
        return RuuviFonts.Typography.Buttons.small().swiftUIFont(size: 14)
    }

    // MARK: - Dynamic Type Support
    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func ruuviLargeTitle() -> SwiftUI.Font {
        return RuuviFonts.DynamicType.largeTitle().swiftUIFont()
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func ruuviTitle1() -> SwiftUI.Font {
        return RuuviFonts.DynamicType.title1().swiftUIFont()
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func ruuviTitle2() -> SwiftUI.Font {
        return RuuviFonts.DynamicType.title2().swiftUIFont()
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func ruuviTitle3() -> SwiftUI.Font {
        return RuuviFonts.DynamicType.title3().swiftUIFont()
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func ruuviHeadline() -> SwiftUI.Font {
        return RuuviFonts.DynamicType.headline().swiftUIFont()
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func ruuviSubheadline() -> SwiftUI.Font {
        return RuuviFonts.DynamicType.subheadline().swiftUIFont()
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func ruuviBody() -> SwiftUI.Font {
        return RuuviFonts.DynamicType.body().swiftUIFont()
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func ruuviCallout() -> SwiftUI.Font {
        return RuuviFonts.DynamicType.callout().swiftUIFont()
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func ruuviFootnote() -> SwiftUI.Font {
        return RuuviFonts.DynamicType.footnote().swiftUIFont()
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func ruuviCaption1() -> SwiftUI.Font {
        return RuuviFonts.DynamicType.caption1().swiftUIFont()
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func ruuviCaption2() -> SwiftUI.Font {
        return RuuviFonts.DynamicType.caption2().swiftUIFont()
    }

#if canImport(SwiftUI)
    /// Get Mulish SwiftUI font
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
    static func mulish(_ weight: RuuviFonts.MulishWeight, size: CGFloat) -> SwiftUI.Font {
        return weight.fontAsset.swiftUIFont(size: size)
    }

    /// Get Montserrat SwiftUI font
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
    static func montserrat(_ weight: RuuviFonts.MontserratWeight, size: CGFloat) -> SwiftUI.Font {
        return weight.fontAsset.swiftUIFont(size: size)
    }

    /// Get Oswald SwiftUI font
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
    static func oswald(_ weight: RuuviFonts.OswaldWeight, size: CGFloat) -> SwiftUI.Font {
        return weight.fontAsset.swiftUIFont(size: size)
    }

    /// Get Mulish SwiftUI font with Dynamic Type
    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func mulish(_ weight: RuuviFonts.MulishWeight, size: CGFloat, relativeTo textStyle: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
        return weight.fontAsset.swiftUIFont(size: size, relativeTo: textStyle)
    }

    /// Get Montserrat SwiftUI font with Dynamic Type
    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func montserrat(_ weight: RuuviFonts.MontserratWeight, size: CGFloat, relativeTo textStyle: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
        return weight.fontAsset.swiftUIFont(size: size, relativeTo: textStyle)
    }

    /// Get Oswald SwiftUI font with Dynamic Type
    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    static func oswald(_ weight: RuuviFonts.OswaldWeight, size: CGFloat, relativeTo textStyle: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
        return weight.fontAsset.swiftUIFont(size: size, relativeTo: textStyle)
    }
#endif
}

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
public extension SwiftUI.Text {
    func ruuviFont(_ asset: FontAsset, size: CGFloat) -> SwiftUI.Text {
        return self.font(.ruuvi(asset, size: size))
    }

    // MARK: - Static Typography Styles
    func ruuviHeadlineLarge() -> SwiftUI.Text {
        return self.font(.ruuviHeadlineLarge())
    }

    func ruuviHeadlineMedium() -> SwiftUI.Text {
        return self.font(.ruuviHeadlineMedium())
    }

    func ruuviHeadlineSmall() -> SwiftUI.Text {
        return self.font(.ruuviHeadlineSmall())
    }

    func ruuviBodyLarge() -> SwiftUI.Text {
        return self.font(.ruuviBodyLarge())
    }

    func ruuviBodyMedium() -> SwiftUI.Text {
        return self.font(.ruuviBodyMedium())
    }

    func ruuviBodySmall() -> SwiftUI.Text {
        return self.font(.ruuviBodySmall())
    }

    func ruuviCaptionLarge() -> SwiftUI.Text {
        return self.font(.ruuviCaptionLarge())
    }

    func ruuviCaptionSmall() -> SwiftUI.Text {
        return self.font(.ruuviCaptionSmall())
    }

    func ruuviButtonLarge() -> SwiftUI.Text {
        return self.font(.ruuviButtonLarge())
    }

    func ruuviButtonMedium() -> SwiftUI.Text {
        return self.font(.ruuviButtonMedium())
    }

    func ruuviButtonSmall() -> SwiftUI.Text {
        return self.font(.ruuviButtonSmall())
    }

    // MARK: - Dynamic Type Support
    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    func ruuviLargeTitle() -> SwiftUI.Text {
        return self.font(.ruuviLargeTitle())
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    func ruuviTitle1() -> SwiftUI.Text {
        return self.font(.ruuviTitle1())
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    func ruuviTitle2() -> SwiftUI.Text {
        return self.font(.ruuviTitle2())
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    func ruuviTitle3() -> SwiftUI.Text {
        return self.font(.ruuviTitle3())
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    func ruuviHeadline() -> SwiftUI.Text {
        return self.font(.ruuviHeadline())
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    func ruuviSubheadline() -> SwiftUI.Text {
        return self.font(.ruuviSubheadline())
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    func ruuviBody() -> SwiftUI.Text {
        return self.font(.ruuviBody())
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    func ruuviCallout() -> SwiftUI.Text {
        return self.font(.ruuviCallout())
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    func ruuviFootnote() -> SwiftUI.Text {
        return self.font(.ruuviFootnote())
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    func ruuviCaption1() -> SwiftUI.Text {
        return self.font(.ruuviCaption1())
    }

    @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
    func ruuviCaption2() -> SwiftUI.Text {
        return self.font(.ruuviCaption2())
    }
}
#endif

// MARK: - Bundle Token

// swiftlint:disable convenience_type
private final class BundleToken {
    static let bundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: BundleToken.self)
        #endif
    }()
}
// swiftlint:enable convenience_type
// swiftlint:enable all
