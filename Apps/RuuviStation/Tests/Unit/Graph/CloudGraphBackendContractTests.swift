@testable import station
@testable import RuuviCloud
@testable import RuuviLocal
import RuuviOntology
import Humidity
import XCTest

@MainActor
final class CloudGraphBackendContractTests: XCTestCase {
    func testRealBackendFixtureMatchesExistingIosHumidityConversionsBeforeAggregation() throws {
        let path = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "backend-contract", withExtension: "json"))
        struct Envelope: Decodable { let data: CloudGraphResponse }
        let response = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: path)).data
        try CloudGraphQuery(sensors: ["AA:BB:CC:DD:EE:FF"], since: 100, until: 120).validate(response)
        let series = try XCTUnwrap(response.series.first)
        // The fixture was emitted by cloud_main's actual GraphAccumulator/graphColumns.
        // Raw RH 40% + 10 percentage points; full-card graphs use raw T for humidity.
        let temperatures = [10.0, 30.0].map { Temperature(value: $0, unit: .celsius) }
        let humidities = temperatures.map { Humidity(value: 0.5, unit: .relative(temperature: $0)) }
        let absolute = humidities.map { $0.converted(to: .absolute).value }
        let dew = try zip(humidities, temperatures).map { try $0.dewPoint(temperature: $1).value }
        for (metric, values) in [(CloudGraphMetricName.absoluteHumidity, absolute), (.dewPoint, dew)] {
            let stats = try XCTUnwrap(series.statistics(metric))
            XCTAssertEqual(try XCTUnwrap(stats.mean), values.reduce(0, +) / 2, accuracy: 1e-10)
            XCTAssertEqual(stats.min, values.min()!, accuracy: 1e-10)
            XCTAssertEqual(stats.max, values.max()!, accuracy: 1e-10)
        }
        XCTAssertEqual(series.statistics(.temperature)?.mean, 25, "Apply temperature offset exactly once")
        XCTAssertEqual(series.statistics(.humidity)?.mean, 50, "Apply RH offset exactly once")
        let settings = RuuviLocalSettingsUserDefaults()
        let viewport = CloudGraphViewport(overview: series)
        for unit in [HumidityUnit.percent, .gm3, .dew] {
            let variant = MeasurementDisplayVariant(type: .humidity, humidityUnit: unit)
            let model = try XCTUnwrap(CloudGraphAdapter.model(viewport: viewport, variant: variant, settings: settings))
            XCTAssertEqual(model.variant, variant, "Preserve the user's selected humidity graph")
        }
    }
}
