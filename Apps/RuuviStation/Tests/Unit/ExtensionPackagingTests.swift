import Foundation
import XCTest

final class ExtensionPackagingTests: XCTestCase {
    func testSharedExtensionFrameworksAreEmbeddedAndLoadable() throws {
        let frameworks = try XCTUnwrap(Bundle.main.privateFrameworksURL)
        for name in ["RuuviWidgets", "RuuviNotificationRemote"] {
            let bundle = try XCTUnwrap(Bundle(url: frameworks.appendingPathComponent(name + ".framework")), name)
            XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(bundle.executableURL).path), name)
            try bundle.loadAndReturnError()
        }
    }

    func testExtensionEntryPointsAndWidgetFontsArePackaged() throws {
        let plugins = try XCTUnwrap(Bundle.main.builtInPlugInsURL)
        let expected = [
            "station.widgets": "com.apple.widgetkit-extension",
            "station.intents": "com.apple.intents-service",
            "station.pnservice": "com.apple.usernotifications.service",
        ]
        for (name, point) in expected {
            let bundle = try XCTUnwrap(Bundle(url: plugins.appendingPathComponent(name + ".appex")), name)
            let metadata = try XCTUnwrap(bundle.infoDictionary?["NSExtension"] as? [String: Any])
            XCTAssertEqual(metadata["NSExtensionPointIdentifier"] as? String, point)
            XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(bundle.executableURL).path), name)
            if name != "station.pnservice" {
                XCTAssertNotNil(
                    bundle.url(forResource: "RuuviWidgetsConfiguration", withExtension: "intentdefinition"), name)
                for language in ["en", "de", "fi", "fr", "pl", "sv"] {
                    XCTAssertNotNil(
                        bundle.url(
                            forResource: "RuuviWidgetsConfiguration", withExtension: "strings",
                            subdirectory: nil, localization: language), "\(name): \(language)")
                }
            }
            if name == "station.widgets" {
                let fonts = try XCTUnwrap(bundle.infoDictionary?["UIAppFonts"] as? [String])
                XCTAssertFalse(fonts.isEmpty)
                for font in fonts { XCTAssertNotNil(bundle.url(forResource: font, withExtension: nil), font) }
            } else {
                XCTAssertFalse(try XCTUnwrap(metadata["NSExtensionPrincipalClass"] as? String).isEmpty)
            }
        }
    }
}
