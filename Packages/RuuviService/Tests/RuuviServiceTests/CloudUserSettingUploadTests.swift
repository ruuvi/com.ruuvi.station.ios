import Foundation
import RuuviCloud
import RuuviOntology
import XCTest
@testable import RuuviService
#if SWIFT_PACKAGE
    @testable import RuuviServiceCloudSync
#endif

@MainActor final class CloudUserSettingUploadTests: XCTestCase {
    private let cases: [(RuuviCloudApiSetting, String)] = [
        (.unitTemperature, "F"), (.unitHumidity, "2"), (.unitPressure, "3"),
        (.accuracyTemperature, "1"), (.accuracyHumidity, "0"), (.accuracyHumidityRelative, "2"),
        (.accuracyHumidityAbsolute, "1"), (.accuracyHumidityDewPoint, "0"), (.accuracyPressure, "2"),
        (.accuracyPM, "1"), (.accuracyAcceleration, "0"), (.accuracyVoltage, "2"),
        (.chartShowAllPoints, "true"), (.chartDrawDots, "false"), (.chartViewPeriod, "24"),
        (.chartShowMinMaxAverage, "true"), (.cloudModeEnabled, "false"), (.dashboardEnabled, "true"),
        (.dashboardType, "simple"), (.dashboardTapActionType, "chart"),
        (.emailAlertDisabled, "true"), (.pushAlertDisabled, "false"), (.marketingPreference, "true"),
        (.profileLanguageCode, "FI"), (.dashboardSensorOrder, "[\"sensor-b\",\"sensor-a\"]"),
    ]

    func testEachSupportedSettingUsesItsCorrectCloudEndpointAndSerializedValue() async {
        let cloud = CloudSpy()
        cloud.allowUserSettingWrites = true
        for (key, value) in cases {
            let setting = RuuviUserSettingStruct(key: key.rawValue, value: value, lastUpdated: nil)
            let handled = await key.upload(userSetting: setting, using: cloud)
            XCTAssertTrue(handled, key.rawValue)
            XCTAssertEqual(cloud.userSettingWrites.last?.0, key)
            XCTAssertEqual(cloud.userSettingWrites.last?.1, value)
        }
        XCTAssertEqual(cloud.userSettingWrites.count, cases.count)
    }

    func testInvalidSerializedValuesAndMismatchedKeysNeverReachTheCloud() async {
        let cloud = CloudSpy()
        for (key, _) in cases where key != .profileLanguageCode {
            let handled = await key.upload(value: "invalid", using: cloud)
            XCTAssertFalse(handled, key.rawValue)
        }
        for key: RuuviCloudApiSetting in [.sensorDescription, .sensorDisplayOrder, .sensorDefaultDisplayOrder] {
            let handled = await key.upload(value: "[]", using: cloud)
            XCTAssertFalse(handled)
        }
        let wrong = RuuviUserSettingStruct(key: "unrelated", value: "F", lastUpdated: nil)
        let handled = await RuuviCloudApiSetting.unitTemperature.upload(userSetting: wrong, using: cloud)
        XCTAssertFalse(handled)
        XCTAssertTrue(cloud.userSettingWrites.isEmpty)
    }

    func testOfflineFailureDoesNotPreventOtherSettingsFromBeingAttempted() async {
        let cloud = CloudSpy()
        for (key, value) in cases {
            // The return value describes whether a setting is supported. Queue/retry
            // ownership belongs to the cloud service, which may fail while offline.
            let handled = await key.upload(value: value, using: cloud)
            XCTAssertTrue(handled, key.rawValue)
        }
        XCTAssertEqual(cloud.userSettingWrites.map(\.0), cases.map(\.0))
        XCTAssertEqual(cloud.userSettingWrites.map(\.1), cases.map(\.1))
    }
}
