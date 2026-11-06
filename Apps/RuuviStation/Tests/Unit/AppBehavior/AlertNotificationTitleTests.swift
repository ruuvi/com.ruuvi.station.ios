import Foundation
import XCTest
@testable import station

final class AlertNotificationTitleTests: XCTestCase {
    func testEveryMeasurementAlertInterpolatesItsValueExactlyOnceAndDistinguishesLowFromHigh() {
        let titles = RuuviNotifierTitlesImpl()
        let pairs: [((String) -> String, (String) -> String)] = [
            (titles.lowTemperature, titles.highTemperature), (titles.lowHumidity, titles.highHumidity),
            (titles.lowAbsoluteHumidity, titles.highAbsoluteHumidity), (titles.lowDewPoint, titles.highDewPoint),
            (titles.lowPressure, titles.highPressure), (titles.lowSignal, titles.highSignal),
            (titles.lowAQI, titles.highAQI), (titles.lowCarbonDioxide, titles.highCarbonDioxide),
            (titles.lowPMatter1, titles.highPMatter1), (titles.lowPMatter25, titles.highPMatter25),
            (titles.lowPMatter4, titles.highPMatter4), (titles.lowPMatter10, titles.highPMatter10),
            (titles.lowVOC, titles.highVOC), (titles.lowNOx, titles.highNOx),
            (titles.lowSoundInstant, titles.highSoundInstant), (titles.lowSoundAverage, titles.highSoundAverage),
            (titles.lowSoundPeak, titles.highSoundPeak), (titles.lowLuminosity, titles.highLuminosity),
            (titles.lowBatteryVoltage, titles.highBatteryVoltage),
        ]
        for (low, high) in pairs {
            let value = "12.34 sensor-unit"
            XCTAssertNotEqual(low(value), high(value))
            for text in [low(value), high(value)] {
                XCTAssertEqual(text.components(separatedBy: value).count, 2)
                XCTAssertFalse(text.contains("%@"))
                XCTAssertFalse(text.contains("%s"))
                XCTAssertGreaterThan(text.count, value.count)
            }
        }
        XCTAssertFalse(titles.didMove.isEmpty)
    }
}
