import Foundation
import XCTest
import RuuviCloud
import RuuviContext
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviStorage
@testable import RuuviService
#if SWIFT_PACKAGE
    import RuuviContextSQLite
    import RuuviLocalUserDefaults
    import RuuviPersistenceSQLite
    import RuuviStorageCoordinator
    @testable import RuuviServiceAppSettings
#endif

final class AppSettingsPersistenceTests: XCTestCase {
    // swiftlint:disable:next function_body_length
    @MainActor func testOfflineSettingsArePersistedBeforeCloudFailure() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("settings.sqlite"))
        let persistence = RuuviPersistenceSQLite(context: context)
        let storage = RuuviStorageFactoryCoordinator().create(sqlite: persistence)
        let settings = RuuviLocalFactoryUserDefaults().createLocalSettings()
        let service = RuuviServiceAppSettingsImpl(cloud: CloudSpy(), localSettings: settings, storage: storage)
        let before = Date().addingTimeInterval(-1)

        struct Change {
            let key: RuuviCloudApiSetting
            let value: String
            let apply: @MainActor () async throws(RuuviServiceError) -> Void
        }
        let changes: [Change] = [
            .init(key: .unitTemperature, value: "F") { () async throws(RuuviServiceError) in
                _ = try await service.set(temperatureUnit: .fahrenheit)
            },
            .init(key: .accuracyTemperature, value: "2") { () async throws(RuuviServiceError) in
                _ = try await service.set(temperatureAccuracy: .two)
            },
            .init(key: .unitHumidity, value: "2") { () async throws(RuuviServiceError) in
                _ = try await service.set(humidityUnit: .dew)
            },
            .init(key: .accuracyHumidity, value: "1") { () async throws(RuuviServiceError) in
                _ = try await service.set(humidityAccuracy: .one)
            },
            .init(key: .accuracyHumidityRelative, value: "2") { () async throws(RuuviServiceError) in
                _ = try await service.set(relativeHumidityAccuracy: .two)
            },
            .init(key: .accuracyHumidityAbsolute, value: "1") { () async throws(RuuviServiceError) in
                _ = try await service.set(absoluteHumidityAccuracy: .one)
            },
            .init(key: .accuracyHumidityDewPoint, value: "2") { () async throws(RuuviServiceError) in
                _ = try await service.set(dewPointAccuracy: .two)
            },
            .init(key: .unitPressure, value: "2") { () async throws(RuuviServiceError) in
                _ = try await service.set(pressureUnit: .millimetersOfMercury)
            },
            .init(key: .accuracyPressure, value: "2") { () async throws(RuuviServiceError) in
                _ = try await service.set(pressureAccuracy: .two)
            },
            .init(key: .accuracyPM, value: "1") { () async throws(RuuviServiceError) in
                _ = try await service.set(pmAccuracy: .one)
            },
            .init(key: .accuracyAcceleration, value: "2") { () async throws(RuuviServiceError) in
                _ = try await service.set(accelerationAccuracy: .two)
            },
            .init(key: .accuracyVoltage, value: "2") { () async throws(RuuviServiceError) in
                _ = try await service.set(voltageAccuracy: .two)
            },
            .init(key: .chartShowAllPoints, value: "true") { () async throws(RuuviServiceError) in
                _ = try await service.set(showAllData: true)
            },
            .init(key: .chartDrawDots, value: "false") { () async throws(RuuviServiceError) in
                _ = try await service.set(drawDots: false)
            },
            .init(key: .chartShowMinMaxAverage, value: "true") { () async throws(RuuviServiceError) in
                _ = try await service.set(showMinMaxAvg: true)
            },
            .init(key: .cloudModeEnabled, value: "false") { () async throws(RuuviServiceError) in
                _ = try await service.set(cloudMode: false)
            },
            .init(key: .dashboardEnabled, value: "true") { () async throws(RuuviServiceError) in
                _ = try await service.set(dashboard: true)
            },
            .init(key: .dashboardType, value: "simple") { () async throws(RuuviServiceError) in
                _ = try await service.set(dashboardType: .simple)
            },
            .init(key: .dashboardTapActionType, value: "chart") { () async throws(RuuviServiceError) in
                _ = try await service.set(dashboardTapActionType: .chart)
            },
            .init(key: .emailAlertDisabled, value: "true") { () async throws(RuuviServiceError) in
                _ = try await service.set(disableEmailAlert: true)
            },
            .init(key: .pushAlertDisabled, value: "false") { () async throws(RuuviServiceError) in
                _ = try await service.set(disablePushAlert: false)
            },
            .init(key: .profileLanguageCode, value: "FI") { () async throws(RuuviServiceError) in
                _ = try await service.set(profileLanguageCode: "FI")
            },
            .init(key: .dashboardSensorOrder, value: "[\"sensor-b\",\"sensor-a\"]") {
                () async throws(RuuviServiceError) in
                _ = try await service.set(dashboardSensorOrder: ["sensor-b", "sensor-a"])
            },
        ]
        for change in changes {
            do {
                try await change.apply()
                XCTFail("Offline cloud operation unexpectedly succeeded: \(change.key)")
            } catch {
                guard case .ruuviCloud(.notAuthorized) = error else {
                    XCTFail("Wrong error for \(change.key): \(error)"); continue
                }
            }
            let stored = try await storage.readUserSetting(for: change.key.rawValue)
            XCTAssertEqual(stored?.value, change.value, change.key.rawValue)
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(stored?.lastUpdated), before)
        }
        let allSettings = try await storage.readUserSettings()
        XCTAssertEqual(allSettings.count, changes.count)
    }
}
