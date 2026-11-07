import Foundation
import RuuviCloud
import RuuviOntology
import XCTest
@testable import RuuviService
#if SWIFT_PACKAGE
    import RuuviServiceCloudSync
#endif

@MainActor final class CloudUserConflictTests: XCTestCase {
    func testTimestampWinnersControlBothStoredAndActiveSettingsAndOnlyChangedValuesUpload() async throws {
        let domain = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        let previous = UserDefaults.standard.persistentDomain(forName: domain) ?? [:]
        let fixture = try CloudSyncFixture()
        defer { fixture.close(); UserDefaults.standard.setPersistentDomain(previous, forName: domain) }
        let earlier = fixture.date
        let later = earlier.addingTimeInterval(60)
        let local: [RuuviUserSetting] = [
            setting(.unitTemperature, "F", later),
            setting(.unitPressure, "0", earlier),
            setting(.chartShowMinMaxAverage, "true", later),
            setting(.accuracyTemperature, "2", later),
        ]
        let cloud: [RuuviUserSetting] = [
            setting(.unitTemperature, "C", earlier),
            setting(.unitPressure, "3", later),
            setting(.chartShowMinMaxAverage, "true", earlier),
            setting(.accuracyTemperature, "0", later),
        ]
        _ = try await fixture.storage.save(userSettings: local)
        fixture.cloud.onSettings = { SyncSettingsFixture(userSettings: cloud) }
        fixture.cloud.allowUserSettingWrites = true
        _ = try await fixture.service.syncSettings()
        XCTAssertEqual(fixture.settings.temperatureUnit, .fahrenheit)
        XCTAssertEqual(fixture.settings.pressureUnit, .inchesOfMercury)
        XCTAssertTrue(fixture.settings.chartStatsOn)
        let writes = fixture.cloud.userSettingWrites
        XCTAssertEqual(writes.filter { $0.0 == .unitTemperature }.map(\.1), ["F"])
        XCTAssertFalse(
            writes.contains { $0.0 == .unitPressure || $0.0 == .chartShowMinMaxAverage || $0.0 == .accuracyTemperature }
        )
        let stored = try await fixture.storage.readUserSettings()
        XCTAssertEqual(stored.first { $0.key == RuuviCloudApiSetting.unitTemperature.rawValue }?.value, "F")
        XCTAssertEqual(stored.first { $0.key == RuuviCloudApiSetting.unitPressure.rawValue }?.value, "3")
        XCTAssertEqual(stored.first { $0.key == RuuviCloudApiSetting.unitPressure.rawValue }?.lastUpdated, later)
        XCTAssertEqual(stored.first { $0.key == RuuviCloudApiSetting.accuracyTemperature.rawValue }?.value, "2")
    }

    func testNewLocalSettingMissingFromCloudUploadsWithoutLosingItsTimestamp() async throws {
        let domain = Bundle.main.bundleIdentifier ?? ProcessInfo.processInfo.processName
        let previous = UserDefaults.standard.persistentDomain(forName: domain) ?? [:]
        let fixture = try CloudSyncFixture()
        defer { fixture.close(); UserDefaults.standard.setPersistentDomain(previous, forName: domain) }
        let local = setting(.unitTemperature, "K", fixture.date)
        _ = try await fixture.storage.save(userSetting: local)
        _ = try await fixture.service.syncSettings()
        XCTAssertEqual(fixture.settings.temperatureUnit, .kelvin)
        XCTAssertEqual(fixture.cloud.userSettingWrites.filter { $0.0 == .unitTemperature }.map(\.1), ["K"])
        let saved = try await fixture.storage.readUserSetting(for: local.key)
        XCTAssertEqual(saved?.value, "K")
        XCTAssertEqual(saved?.lastUpdated, fixture.date)
    }

    private func setting(_ key: RuuviCloudApiSetting, _ value: String, _ date: Date) -> RuuviUserSettingStruct {
        .init(key: key.rawValue, value: value, lastUpdated: date)
    }
}
