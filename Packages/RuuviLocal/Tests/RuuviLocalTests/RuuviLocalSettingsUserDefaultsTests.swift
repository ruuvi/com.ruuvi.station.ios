@testable import RuuviLocalUserDefaults
import Foundation
import RuuviLocal
import XCTest

final class RuuviLocalSettingsUserDefaultsTests: XCTestCase {
    private let syncedKeys = [
        "SettingsUserDegaults.temperatureUnitIntUDKey",
        "SettingsUserDegaults.useFahrenheit",
        "SettingsUserDefaults.temperatureAccuracyInt",
        "SettingsUserDegaults.humidityUnitInt",
        "SettingsUserDefaults.humidityAccuracyInt",
        "SettingsUserDefaults.relativeHumidityAccuracyInt",
        "SettingsUserDefaults.absoluteHumidityAccuracyInt",
        "SettingsUserDefaults.dewPointAccuracyInt",
        "SettingsUserDefaults.pressureUnitInt",
        "SettingsUserDefaults.pressureAccuracyInt",
        "SettingsUserDefaults.pmAccuracyInt",
        "SettingsUserDefaults.accelerationAccuracyInt",
        "SettingsUserDefaults.voltageAccuracyInt",
        "SettingsUserDefaults.chartDownsamplingOn",
        "SettingsUserDefaults.chartDrawDotsOn",
        "SettingsUserDefaults.chartStatsOn",
        "SettingsUserDefaults.cloudModeEnabled",
        "SettingsUserDefaults.dashboardEnabled",
        "SettingsUserDefaults.dashboardTypeIdKey",
        "SettingsUserDefaults.dashboardTapActionTypeIdKey",
        "SettingsUserDefaults.dashboardSortedSensors",
        "SettingsUserDefaults.emailAlertDisabled",
        "SettingsUserDefaults.pushAlertDisabled",
        "SettingsUserDefaults.marketingPreference",
        "SettingsUserDefaults.cardToOpenFromWidgetKey",
    ]

    override func tearDown() {
        syncedKeys.forEach(UserDefaults.standard.removeObject(forKey:))
        UserDefaults.standard.removeObject(
            forKey: "SettingsUserDegaults.saveHeartbeatsIntervalMinutes"
        )
        UserDefaults.standard.removeObject(
            forKey: "SettingsUserDefaults.appOpenedCount"
        )
        super.tearDown()
    }

    func testResetCloudProfileSettingsClearsOnlySyncedValues() {
        syncedKeys.forEach { UserDefaults.standard.set(true, forKey: $0) }
        UserDefaults.standard.set(
            42,
            forKey: "SettingsUserDegaults.saveHeartbeatsIntervalMinutes"
        )
        UserDefaults.standard.set(1, forKey: "SettingsUserDefaults.appOpenedCount")
        let settings = RuuviLocalSettingsUserDefaults()

        settings.resetCloudProfileSettings()

        syncedKeys.forEach {
            XCTAssertNil(UserDefaults.standard.object(forKey: $0), $0)
        }
        XCTAssertEqual(settings.temperatureUnit, .celsius)
        XCTAssertEqual(settings.temperatureAccuracy, .two)
        XCTAssertEqual(settings.humidityUnit, .percent)
        XCTAssertEqual(settings.humidityAccuracy, .two)
        XCTAssertEqual(settings.relativeHumidityAccuracy, .two)
        XCTAssertEqual(settings.absoluteHumidityAccuracy, .two)
        XCTAssertEqual(settings.dewPointAccuracy, .two)
        XCTAssertEqual(settings.pressureUnit, .hectopascals)
        XCTAssertEqual(settings.pressureAccuracy, .two)
        XCTAssertEqual(settings.pmAccuracy, .one)
        XCTAssertEqual(settings.accelerationAccuracy, .two)
        XCTAssertEqual(settings.voltageAccuracy, .two)
        XCTAssertFalse(settings.chartDownsamplingOn)
        XCTAssertFalse(settings.chartDrawDotsOn)
        XCTAssertTrue(settings.chartStatsOn)
        XCTAssertFalse(settings.cloudModeEnabled)
        XCTAssertTrue(settings.dashboardEnabled)
        XCTAssertEqual(settings.dashboardType, .image)
        XCTAssertEqual(settings.dashboardTapActionType, .card)
        XCTAssertEqual(settings.dashboardSensorOrder, [])
        XCTAssertFalse(settings.emailAlertDisabled)
        XCTAssertFalse(settings.pushAlertDisabled)
        XCTAssertFalse(settings.marketingPreference)
        XCTAssertNil(settings.cloudProfileLanguageCode)
        XCTAssertEqual(settings.saveHeartbeatsIntervalMinutes, 42)
        XCTAssertEqual(settings.appOpenedCount, 1)
    }

    func testResetCloudProfileSettingsDoesNotBroadcastPreferenceChanges() {
        let settings = RuuviLocalSettingsUserDefaults()
        let noNotification = expectation(description: "No preference notifications")
        noNotification.isInverted = true
        let names: [Notification.Name] = [
            .TemperatureUnitDidChange,
            .TemperatureAccuracyDidChange,
            .HumidityUnitDidChange,
            .HumidityAccuracyDidChange,
            .MeasurementAccuracyDidChange,
            .PressureUnitDidChange,
            .PressureUnitAccuracyChange,
            .ChartDrawDotsOnDidChange,
            .ChartStatsOnDidChange,
            .CloudModeDidChange,
            .DashboardTypeDidChange,
            .DashboardTapActionTypeDidChange,
            .DashboardSensorOrderDidChange,
            .EmailAlertSettingsDidChange,
            .PushAlertSettingsDidChange,
            .MarketingPreferenceDidChange,
        ]
        let tokens = names.map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: settings,
                queue: nil
            ) { _ in
                noNotification.fulfill()
            }
        }
        defer {
            tokens.forEach(NotificationCenter.default.removeObserver)
        }

        settings.resetCloudProfileSettings()

        wait(for: [noNotification], timeout: 0.2)
    }
}
