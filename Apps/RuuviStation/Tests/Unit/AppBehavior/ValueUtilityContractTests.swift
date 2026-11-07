import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

final class ValueUtilityContractTests: XCTestCase {
    func testHumidityOffsetRequiresBothCalibrationAndTemperatureAndAddsRelativeFraction() throws {
        let temperature = Temperature(value: 20, unit: .celsius)
        let humidity = try XCTUnwrap(Humidity(relative: 0.5, temperature: temperature))
        XCTAssertNil(humidity.offseted(by: nil, temperature: temperature))
        XCTAssertNil(humidity.offseted(by: 0.1, temperature: nil))
        let positive = try XCTUnwrap(humidity.offseted(by: 0.1, temperature: temperature))
        let negative = try XCTUnwrap(humidity.offseted(by: -0.1, temperature: temperature))
        XCTAssertEqual(positive.converted(to: .relative(temperature: temperature)).value, 0.6, accuracy: 0.000001)
        XCTAssertEqual(negative.converted(to: .relative(temperature: temperature)).value, 0.4, accuracy: 0.000001)
    }

    func testHexAndRGBColorsRetainChannelValuesAndAlpha() {
        for color in [UIColor(hex: 0x1A80FF, alpha: 0.25), UIColor(hexString: " \n#1a80ff ", alpha: 0.25)] {
            var red: CGFloat = 0; var green: CGFloat = 0; var blue: CGFloat = 0; var alpha: CGFloat = 0
            XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            XCTAssertEqual(red, 26.0 / 255, accuracy: 0.00001)
            XCTAssertEqual(green, 128.0 / 255, accuracy: 0.00001)
            XCTAssertEqual(blue, 1, accuracy: 0.00001)
            XCTAssertEqual(alpha, 0.25, accuracy: 0.00001)
        }
        XCTAssertEqual(UIColor.rgb(r: 26, g: 128, b: 255), UIColor(hexString: "1A80FF"))
    }

    func testOptionalPreferencesDistinguishMissingValuesFromZeroAndFalse() throws {
        let suite = "OptionalPreferenceTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertNil(defaults.optionalDouble(forKey: "decimal"))
        XCTAssertNil(defaults.optionalInt(forKey: "integer"))
        XCTAssertNil(defaults.optionalBool(forKey: "flag"))
        defaults.set(0.0, forKey: "decimal")
        defaults.set(0, forKey: "integer")
        defaults.set(false, forKey: "flag")
        XCTAssertEqual(defaults.optionalDouble(forKey: "decimal"), 0)
        XCTAssertEqual(defaults.optionalInt(forKey: "integer"), 0)
        XCTAssertEqual(defaults.optionalBool(forKey: "flag"), false)
        defaults.set("invalid", forKey: "decimal")
        defaults.set("invalid", forKey: "integer")
        defaults.set("invalid", forKey: "flag")
        XCTAssertNil(defaults.optionalDouble(forKey: "decimal"))
        XCTAssertNil(defaults.optionalInt(forKey: "integer"))
        XCTAssertNil(defaults.optionalBool(forKey: "flag"))
    }

    func testEmailExtractionKeepsTheFirstAddressAndDeviceLabelsRemainDistinct() {
        XCTAssertEqual("Contact OWNER@EXAMPLE.COM now".email(), "owner@example.com")
        XCTAssertEqual("first@example.com second@example.com".email(), "first@example.com")
        XCTAssertNil("Contact the owner".email())
        XCTAssertEqual(RuuviDeviceType.ruuviTag.displayName, RuuviLocalization.ruuviTag)
        XCTAssertEqual(RuuviDeviceType.ruuviAir.displayName, RuuviLocalization.ruuviAir)
        XCTAssertEqual(RuuviDeviceType.ruuviTag.fwVersionPrefix, "Ruuvi FW")
        XCTAssertEqual(RuuviDeviceType.ruuviAir.fwVersionPrefix, "RuuviAir")
    }
}
