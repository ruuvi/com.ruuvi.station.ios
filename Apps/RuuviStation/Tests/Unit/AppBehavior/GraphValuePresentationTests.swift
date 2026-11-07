import DGCharts
import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class GraphValuePresentationTests: XCTestCase {
    func testGraphReadoutsUseEachVariantsPrecisionRatherThanTheCurrentlySelectedGlobalUnit() throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        fixture.settings.temperatureAccuracy = .one
        fixture.settings.relativeHumidityAccuracy = .zero
        fixture.settings.absoluteHumidityAccuracy = .two
        fixture.settings.dewPointAccuracy = .one
        fixture.settings.pressureAccuracy = .two
        fixture.settings.voltageAccuracy = .two
        fixture.settings.accelerationAccuracy = .one
        fixture.settings.humidityUnit = .percent
        fixture.settings.pressureUnit = .hectopascals
        let cases: [(MeasurementDisplayVariant, String)] = [
            (.init(type: .temperature, temperatureUnit: .fahrenheit), "23.5"),
            (.init(type: .humidity, humidityUnit: .percent), "23"),
            (.init(type: .humidity, humidityUnit: .gm3), "23.46"),
            (.init(type: .humidity, temperatureUnit: .kelvin, humidityUnit: .dew), "23.5"),
            (.init(type: .pressure, pressureUnit: .newtonsPerMetersSquared), "23"),
            (.init(type: .pressure, pressureUnit: .inchesOfMercury), "23.46"),
            (.init(type: .voltage), "23.46"),
            (.init(type: .accelerationX), "23.5"),
            (.init(type: .accelerationY), "23.5"),
            (.init(type: .accelerationZ), "23.5"),
        ]
        for (variant, expected) in cases {
            let view = CardsGraphView(variant: variant)
            view.setSettings(settings: fixture.settings)
            view.setChartLabel(type: variant.type, measurementService: fixture.measurement, unit: "unit")
            view.updateLatest(
                with: ChartDataEntry(x: 1, y: 23.456), isHighlighted: true,
                type: variant.type, measurementService: fixture.measurement)
            let latest = try XCTUnwrap(
                view.allDescendants.compactMap { $0 as? UILabel }.first { $0.textAlignment == .right })
            XCTAssertEqual(latest.text, localized(expected), "\(variant)")
            XCTAssertEqual(latest.textColor, RuuviColor.orangeColor.color)
            view.setChartStat(
                min: 23.456, max: 23.456, avg: 23.456,
                type: variant.type, measurementService: fixture.measurement)
            XCTAssertTrue(
                view.allDescendants.compactMap { ($0 as? UILabel)?.text }.contains(
                    RuuviLocalization.chartMinMaxAvg(localized(expected), localized(expected), localized(expected))))
            view.updateLatest(
                with: nil, isHighlighted: false, type: variant.type, measurementService: fixture.measurement)
            XCTAssertEqual(latest.text, "")
            XCTAssertEqual(latest.textColor, .white)
        }
    }

    func testValuesThatRoundToZeroDoNotDisplayNegativeZeroAndAQIHasItsScaleSuffix() throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let view = CardsGraphView(variant: .init(type: .temperature))
        view.setSettings(settings: fixture.settings)
        view.updateLatest(
            with: ChartDataEntry(x: 1, y: -0.004), isHighlighted: false,
            type: .temperature, measurementService: fixture.measurement)
        let latest = try XCTUnwrap(
            view.allDescendants.compactMap { $0 as? UILabel }.first { $0.textAlignment == .right })
        XCTAssertEqual(latest.text, localized("0.00"))
        let aqi = CardsGraphView(variant: .init(type: .aqi))
        aqi.setSettings(settings: fixture.settings)
        aqi.setChartLabel(type: .aqi, measurementService: fixture.measurement, unit: "AQI")
        aqi.updateLatest(
            with: ChartDataEntry(x: 1, y: 83.456), isHighlighted: false,
            type: .aqi, measurementService: fixture.measurement)
        let labels = aqi.allDescendants.compactMap { ($0 as? UILabel)?.text }
        XCTAssertTrue(labels.contains("83"))
        XCTAssertTrue(labels.contains("/100"))
        aqi.updateLatest(with: nil, isHighlighted: false, type: .aqi, measurementService: fixture.measurement)
        XCTAssertFalse(aqi.allDescendants.compactMap { ($0 as? UILabel)?.text }.contains("/100"))
    }
    private func localized(_ value: String) -> String {
        value.replacingOccurrences(of: ".", with: Locale.current.decimalSeparator ?? ".")
    }
}
