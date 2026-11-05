import Foundation
import RuuviOntology
import XCTest
@testable import RuuviWidgets

@MainActor final class WidgetFormattingTests: XCTestCase {
    func testPrecisionIsRetainedForTemperatureHumidityAndPressure() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let service = MeasurementService(settings: fixture.model.getAppSettings())
        let separator = Locale.autoupdatingCurrent.decimalSeparator ?? "."
        XCTAssertEqual(service.temperature(for: .init(value: 20, unit: .celsius)), "20" + separator + "00")
        XCTAssertEqual(
            service.humidity(
                for: .init(relative: 0.5, temperature: .init(value: 20, unit: .celsius)),
                temperature: .init(value: 20, unit: .celsius), isDecimal: false), "50" + separator + "00")
        XCTAssertEqual(service.pressure(for: .init(value: 999, unit: .hectopascals)), "999" + separator + "00")
    }

    func testInvalidAndMissingPressureNeverTrapsOrDisplaysNonfiniteValues() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.defaults.set(UnitPressure.newtonsPerMetersSquared.hashValue, forKey: Constants.pressureUnitKey.rawValue)
        let service = MeasurementService(settings: fixture.model.getAppSettings())
        for value in [Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(service.pressure(for: .init(value: value, unit: .hectopascals)), "-")
            XCTAssertEqual(service.temperature(for: .init(value: value, unit: .celsius)), "-")
            XCTAssertEqual(service.acceleration(for: value), "-")
            XCTAssertEqual(service.string(for: value), "-")
            XCTAssertEqual(service.pm(for: value), "-")
        }
        XCTAssertEqual(service.pressure(for: nil), "-")
        XCTAssertEqual(service.temperature(for: nil), "-")
        XCTAssertEqual(service.voltage(for: nil), "-")
        XCTAssertEqual(service.acceleration(for: nil), "-")
        XCTAssertEqual(service.movements(for: nil), "-")
        XCTAssertEqual(service.pm(for: nil), "-")
        XCTAssertEqual(service.string(for: nil), "-")
    }

    func testAirQualityBoundariesAndProgressStayBounded() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let service = MeasurementService(settings: fixture.model.getAppSettings())
        XCTAssertEqual(service.aqiDisplay(for: 420, and: 0).currentScore, 100)
        XCTAssertEqual(service.aqiDisplay(for: 2300, and: 60).currentScore, 0)
        XCTAssertEqual(service.aqiDisplay(for: nil, and: 0).currentScore, 0)
        XCTAssertEqual(service.aqiDisplay(for: .nan, and: 0).currentScore, 0)
        for score in [95, 85, 65, 25, 0] {
            let co2 = 420 + Double(100 - score) / 100 * 1880
            XCTAssertEqual(service.aqiDisplay(for: co2, and: 0).currentScore, score)
        }
        XCTAssertEqual(WidgetAirQualityDisplay(currentScore: 120, maxScore: 100, state: .excellent(100)).progress, 1)
        XCTAssertEqual(WidgetAirQualityDisplay(currentScore: -10, maxScore: 100, state: .undefined(0)).progress, 0)
        XCTAssertEqual(WidgetAirQualityDisplay(currentScore: 10, maxScore: 0, state: .undefined(0)).progress, 0)
        XCTAssertEqual(WidgetAirQualityDisplay(currentScore: 25, maxScore: 100, state: .poor(25)).progress, 0.25)
    }
}
