import XCTest
@testable import station

final class NumericUtilityContractTests: XCTestCase {
    func testTemperatureAndPressureHelpersPreserveTheirExistingUnitsAndPrecision() {
        XCTAssertEqual(0.0.fahrenheit, 32)
        XCTAssertEqual(100.0.fahrenheit, 212)
        XCTAssertEqual((-40.0).celsiusFromFahrenheit, -40)
        XCTAssertEqual(32.0.celsiusFromFahrenheit, 0)
        XCTAssertEqual(0.0.kelvin, 273.15)
        XCTAssertEqual(0.0.celsiusFromKelvin, -273.15)
        XCTAssertEqual(1000.0.inHg, 29.53, accuracy: 0.000001)
        XCTAssertEqual(1000.0.mmHg, 750.06, accuracy: 0.000001)
        XCTAssertEqual(29.53.hPaFrominHg, 1000, accuracy: 0.01)
        XCTAssertEqual(750.06.hPaFrommmHg, 1000, accuracy: 0.01)
        XCTAssertEqual(101325.0.hPaFromPa, 1013.25)
        XCTAssertEqual(12.0.decimalPoint, 0)
        XCTAssertEqual((-12.5).decimalPoint, 1)
        XCTAssertEqual(12.125.decimalPoint, 3)
        XCTAssertEqual((-12.9).intValue, -12)
        XCTAssertEqual(Optional(12.9).intValue, 12)
        XCTAssertEqual(Optional<Double>.none.intValue, 0)
    }
}
