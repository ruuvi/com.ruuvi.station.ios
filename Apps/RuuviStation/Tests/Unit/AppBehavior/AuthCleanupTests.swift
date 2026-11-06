import Foundation
import RuuviLocal
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class AuthCleanupTests: XCTestCase {
    func testLogoutRemovesCloudSensorsAndTheirHistoryAndPreferencesWhileKeepingLocalSensors() async throws {
        let fixture = AuthCleanupFixture()
        defer { fixture.cleanup() }
        var cloud = fixture.data.sensor("Cloud", cloud: true)
        cloud.isClaimed = true
        var claimed = fixture.data.sensor("Claimed")
        claimed.isClaimed = true
        let local = fixture.data.sensor("Local")
        fixture.data.measurements.storage.sensorsOverride = [cloud.any, claimed.any, local.any]
        let settings = fixture.data.measurements.settings
        let sync = fixture.sync
        let date = Date()
        for sensor in [cloud, claimed] {
            sync.setSyncDate(date, for: sensor.macId)
            sync.setGattSyncDate(date, for: sensor.macId)
            sync.setAutoGattSyncAttemptDate(date, for: sensor.macId)
            settings.setOwnerCheckDate(for: sensor.macId, value: date)
            settings.setKeepConnectionDialogWasShown(true, for: sensor.luid!)
            settings.setFirmwareUpdateDialogWasShown(true, for: sensor.luid!)
            settings.setSyncDialogHidden(true, for: sensor.luid!)
            settings.setShowCustomTempAlertBound(true, for: sensor.id)
            settings.setShowCustomCO2AlertBound(true, for: sensor.id)
            settings.setShowCustomPMAlertBound(true, for: sensor.id)
            fixture.data.measurements.alerts.register(type: .temperature(lower: 0, upper: 20), ruuviTag: sensor)
        }
        sync.setSyncDate(date)
        settings.setCardToOpenFromWidget(for: cloud.macId!.value)
        settings.setLastOpenedChart(with: claimed.id)
        let notifications = AuthNotificationRecorder()
        let result = try await fixture.service.logout()
        XCTAssertTrue(result)
        XCTAssertFalse(fixture.user.isAuthorized)
        XCTAssertNil(fixture.user.apiKey)
        XCTAssertEqual(
            fixture.pool.deletionCalls.map(\.0),
            ["sensor", "history", "latest", "sensor", "history", "latest", "queue", "settings"])
        XCTAssertEqual(fixture.pool.deletionCalls.filter { $0.0 == "sensor" }.compactMap(\.1), [cloud.id, claimed.id])
        XCTAssertEqual(fixture.data.properties.removedImages, [cloud.id, claimed.id])
        for sensor in [cloud, claimed] {
            XCTAssertNil(sync.getSyncDate(for: sensor.macId))
            XCTAssertNil(sync.getGattSyncDate(for: sensor.macId))
            XCTAssertNil(sync.getAutoGattSyncAttemptDate(for: sensor.macId))
            XCTAssertNil(settings.ownerCheckDate(for: sensor.macId))
            XCTAssertFalse(settings.keepConnectionDialogWasShown(for: sensor.luid!))
            XCTAssertFalse(settings.firmwareUpdateDialogWasShown(for: sensor.luid!))
            XCTAssertFalse(settings.syncDialogHidden(for: sensor.luid!))
            XCTAssertFalse(settings.showCustomTempAlertBound(for: sensor.id))
            XCTAssertFalse(settings.showCustomCO2AlertBound(for: sensor.id))
            XCTAssertFalse(settings.showCustomPMAlertBound(for: sensor.id))
            XCTAssertFalse(fixture.data.measurements.alerts.isOn(type: .temperature(lower: 0, upper: 20), for: sensor))
        }
        XCTAssertNil(sync.getSyncDate())
        XCTAssertNil(settings.cardToOpenFromWidget())
        XCTAssertNil(settings.lastOpenedChart())
        XCTAssertEqual(settings.resetCount, 1)
        XCTAssertEqual(notifications.events, ["will", "finish:true", "did"])
    }

    func testReadFailureReportsFailedLogoutWithoutDeletingUnknownSensors() async {
        let fixture = AuthCleanupFixture()
        defer { fixture.cleanup() }
        fixture.data.measurements.storage.failReadAll = true
        let notifications = AuthNotificationRecorder()
        do { _ = try await fixture.service.logout(); XCTFail("Failed read reported success") } catch {
            guard case .ruuviStorage = error else { return XCTFail("Unexpected \(error)") }
        }
        XCTAssertTrue(fixture.pool.deletionCalls.isEmpty)
        XCTAssertFalse(fixture.user.isAuthorized)
        XCTAssertEqual(notifications.events, ["will", "finish:false"])
    }

    func testDeleteFailureDoesNotReportSuccessfulLogoutOrProceedToGlobalDeletion() async {
        let fixture = AuthCleanupFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.data.sensor("Cloud", cloud: true)
        fixture.data.measurements.storage.sensorsOverride = [sensor.any]
        fixture.pool.deletionFailure = .ruuviPersistence(.failedToFindRuuviTag)
        let notifications = AuthNotificationRecorder()
        do { _ = try await fixture.service.logout(); XCTFail("Failed deletion reported success") } catch {
            guard case .ruuviPool = error else { return XCTFail("Unexpected \(error)") }
        }
        XCTAssertEqual(fixture.pool.deletionCalls.map(\.0), ["sensor"])
        XCTAssertTrue(fixture.data.properties.removedImages.isEmpty)
        XCTAssertEqual(notifications.events, ["will", "finish:false"])
    }
}

@MainActor private final class AuthCleanupFixture {
    let data = SensorDataFixture()
    let pool = AppPoolSpy()
    let sync = AppSyncStateSpy()
    let user = DefaultsUserSpy()
    lazy var service = RuuviServiceAuthImpl(
        ruuviUser: user, pool: pool, storage: data.measurements.storage,
        propertiesService: data.properties,
        localIDs: AppAssembly.shared.assembler.resolver.resolve(RuuviLocalIDs.self)!,
        localSyncState: sync, alertService: data.measurements.alerts, settings: data.measurements.settings)
    init() { user.isAuthorized = true; pool.allowDeletes = true }
    func cleanup() { data.cleanup(); data.measurements.cleanup() }
}

private final class AuthNotificationRecorder {
    private(set) var events = [String]()
    private var tokens = [NSObjectProtocol]()
    init() {
        for (name, label): (Notification.Name, String) in [
            (.RuuviAuthServiceWillLogout, "will"),
            (.RuuviAuthServiceLogoutDidFinish, "finish"), (.RuuviAuthServiceDidLogout, "did"),
        ] {
            tokens.append(
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                    if label == "finish",
                        let success = note.userInfo?[RuuviAuthServiceLogoutDidFinishKey.success] as? Bool
                    {
                        self?.events.append("finish:\(success)")
                    } else {
                        self?.events.append(label)
                    }
                })
        }
    }
    deinit { tokens.forEach(NotificationCenter.default.removeObserver) }
}
