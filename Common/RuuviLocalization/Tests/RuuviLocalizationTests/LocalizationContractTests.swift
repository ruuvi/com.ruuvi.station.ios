import Foundation
import XCTest
@testable import RuuviLocalization

struct LocalizedStringContract {
    let key: String
    let arguments: [CVarArg]
    let defaultValue: () -> String
    let localized: (Locale?) -> String
}

final class LocalizationContractTests: XCTestCase {
    func testSwedishThresholdAlertsContainOneInterpolatedValueWithoutPlatformSyntax() {
        let locale = Locale(identifier: "sv_SE")
        let cases: [(String, String)] = [
            (RuuviLocalization.alertNotificationVocHighThreshold("123", locale), "VOC-index är över 123"),
            (RuuviLocalization.alertNotificationNoxHighThreshold("123", locale), "NOx-index är över 123"),
            (RuuviLocalization.alertNotificationPm1HighThreshold("123", locale), "PM1.0 är över 123"),
            (RuuviLocalization.alertNotificationPm10HighThreshold("123", locale), "PM10.0 är över 123"),
            (RuuviLocalization.alertNotificationPm25HighThreshold("123", locale), "PM2.5 är över 123"),
            (RuuviLocalization.alertNotificationPm4HighThreshold("123", locale), "PM4.0 är över 123"),
        ]
        for (actual, expected) in cases { XCTAssertEqual(actual, expected) }
    }

    func testPublicAccessorsCoverThePackagedEnglishCatalogExactlyOnce() throws {
        let english = try strings(language: "en")
        let keys = LocalizationCatalog.all.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertEqual(Set(keys), Set(english.keys))
    }

    func testEveryAccessorUsesTheRequestedLanguageAndPreservesFormatArguments() throws {
        let english = try strings(language: "en")
        for identifier in ["en_US", "fi_FI", "sv_SE", "fr_FR", "de_DE", "pl_PL"] {
            let locale = Locale(identifier: identifier)
            let language = String(identifier.prefix(2))
            let translations = try strings(language: language)
            XCTAssertEqual(Set(translations.keys), Set(english.keys), language)
            for entry in LocalizationCatalog.all {
                let format = try XCTUnwrap(translations[entry.key], "\(identifier): \(entry.key)")
                let reference = try XCTUnwrap(english[entry.key])
                guard argumentTypes(format) == argumentTypes(reference) else {
                    XCTFail("\(identifier): \(entry.key) changed its interpolation arguments")
                    continue
                }
                XCTAssertEqual(
                    entry.localized(locale),
                    String(format: format, locale: locale, arguments: entry.arguments),
                    "\(identifier): \(entry.key)")
            }
        }
    }

    func testDefaultNilAndUnsupportedLanguageAccessorsUseTheBundleFallback() throws {
        for entry in LocalizationCatalog.all {
            let missing = "__MISSING_TRANSLATION__"
            let format = LocalizationTestBundle.bundle.localizedString(
                forKey: entry.key, value: missing, table: "Localizable")
            XCTAssertNotEqual(format, missing, "Missing bundled string: \(entry.key)")
            let expected = String(format: format, locale: Locale.current, arguments: entry.arguments)
            XCTAssertEqual(entry.defaultValue(), expected, entry.key)
            XCTAssertEqual(entry.localized(nil), expected, entry.key)
            let unsupported = Locale(identifier: "zz_ZZ")
            XCTAssertEqual(
                entry.localized(unsupported),
                String(format: format, locale: unsupported, arguments: entry.arguments), entry.key)
        }
    }

    private func strings(language: String) throws -> [String: String] {
        let url = try XCTUnwrap(
            LocalizationTestBundle.bundle.url(
                forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language))
        return try XCTUnwrap(
            PropertyListSerialization.propertyList(
                from: Data(contentsOf: url), options: [], format: nil) as? [String: String])
    }

    private func argumentTypes(_ value: String) -> [String] {
        let value = value.replacingOccurrences(of: "%%", with: "")
        let pattern = #"%(\d+\$)?[-+#0 ']*(\d+|\*)?(\.\d+)?[hlLjztq]*([@diuoxXfFeEgGaAcCsSp])"#
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).map { match in
            String(value[Range(match.range(at: 4), in: value)!])
        }
    }
}

enum LocalizationTestBundle {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
            return Bundle.module
        #else
            return Bundle(for: ColorAsset.self)
        #endif
    }
}
