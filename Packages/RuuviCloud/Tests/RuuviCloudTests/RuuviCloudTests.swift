@testable import RuuviCloud
import XCTest

final class RuuviCloudTests: XCTestCase {
    func testRegister() {}

    func testDenseSensorSettingsDecodeOffsetValuesAndTimestamps() throws {
        let json = #"""
        {
          "offsetTemperature": "1.25",
          "offsetHumidity": "2.5",
          "offsetPressure": "300",
          "offsetTemperature_lastUpdated": 1700000001,
          "offsetHumidity_lastUpdated": 1700000002,
          "offsetPressure_lastUpdated": 1700000003
        }
        """#.data(using: .utf8)!

        let settings = try JSONDecoder().decode(
            RuuviCloudApiGetSensorsDenseResponse.CloudApiSensor.CloudApiSensorSettings.self,
            from: json
        )

        XCTAssertEqual(settings.offsetTemperature, 1.25)
        XCTAssertEqual(settings.offsetHumidity, 2.5)
        XCTAssertEqual(settings.offsetPressure, 300)
        XCTAssertEqual(settings.offsetTemperatureLastUpdated, 1_700_000_001)
        XCTAssertEqual(settings.offsetHumidityLastUpdated, 1_700_000_002)
        XCTAssertEqual(settings.offsetPressureLastUpdated, 1_700_000_003)
    }
}
