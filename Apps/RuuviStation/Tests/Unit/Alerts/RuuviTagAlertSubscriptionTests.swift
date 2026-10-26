@testable import station
import RuuviCore
import RuuviNotifier
import RuuviOntology
import RuuviService
import Swinject
import XCTest

final class RuuviTagAlertSubscriptionTests: XCTestCase {
    @MainActor func testSignInUpdatesCloudAlertBellsWithoutRestart() async {
        let fixture = AlertSubscriptionFixture(isCloud: false)
        defer { fixture.cleanUp() }
        fixture.load()
        await fixture.settle()

        fixture.snapshot.metadata.isCloud = true
        fixture.snapshot.latestRawRecord = fixture.record(isCloud: true)
        fixture.update()
        fixture.process()
        await fixture.settle()

        fixture.assertFiring(true)
    }

    @MainActor func testBulkCloudImportUpdatesBellsAfterInitialSetup() async {
        let fixture = AlertSubscriptionFixture(isCloud: true)
        defer { fixture.cleanUp() }
        let existing = RuuviTagCardSnapshot.create(
            id: UUID().uuidString, name: "Existing local sensor", luid: UUID().uuidString.luid,
            mac: nil, serviceUUID: nil, isCloud: false, isOwner: true,
            isConnectable: true, version: 5
        )
        fixture.load([existing])
        await fixture.settle()

        fixture.snapshot.latestRawRecord = fixture.record(isCloud: true)
        // Cloud sync suppresses didAddNewSensor and finishes with a bulk snapshot update.
        fixture.load([existing, fixture.snapshot])
        fixture.process()
        await fixture.settle()

        fixture.assertFiring(true)
    }

    @MainActor func testAlreadySignedInAtLaunchStillUpdatesBells() async {
        let fixture = AlertSubscriptionFixture(isCloud: true)
        defer { fixture.cleanUp() }
        fixture.snapshot.latestRawRecord = fixture.record(isCloud: true)
        fixture.load()
        await fixture.settle()

        fixture.assertFiring(true)
    }

    @MainActor func testLateBluetoothCallbackCannotOverwriteCloudAlerts() async {
        let fixture = AlertSubscriptionFixture(isCloud: false)
        defer { fixture.cleanUp() }
        fixture.load()
        await fixture.settle()
        fixture.snapshot.metadata.isCloud = true
        fixture.snapshot.latestRawRecord = fixture.record(isCloud: true)
        fixture.update()
        fixture.process()
        await fixture.settle()
        fixture.assertFiring(true)

        fixture.deliverUntriggeredCallbacks(for: fixture.luid.value)
        await fixture.settle()

        fixture.assertFiring(true)
    }

    @MainActor func testReturningToLocalModeUsesBluetoothAndIgnoresCloudCallbacks() async {
        let fixture = AlertSubscriptionFixture(isCloud: true)
        defer { fixture.cleanUp() }
        fixture.load()
        await fixture.settle()
        fixture.snapshot.metadata.isCloud = false
        fixture.snapshot.connectionData.isConnected = true
        fixture.snapshot.latestRawRecord = fixture.record(isCloud: false)
        fixture.update()
        fixture.process()
        await fixture.settle()
        fixture.assertFiring(true)

        fixture.deliverUntriggeredCallbacks(for: fixture.mac!.value)
        await fixture.settle()
        fixture.assertFiring(true)

        fixture.snapshot.latestRawRecord = fixture.record(isCloud: false, safe: true)
        fixture.process()
        await fixture.settle()
        fixture.assertFiring(false)
    }

    @MainActor func testLocalSensorWithoutMACStillTriggersAndClearsAlerts() async {
        let fixture = AlertSubscriptionFixture(isCloud: false, hasMAC: false)
        defer { fixture.cleanUp() }
        fixture.snapshot.latestRawRecord = fixture.record(isCloud: false)
        fixture.load()
        await fixture.settle()
        fixture.assertFiring(true)

        fixture.snapshot.latestRawRecord = fixture.record(isCloud: false, safe: true)
        fixture.process()
        await fixture.settle()
        fixture.assertFiring(false)
    }

    @MainActor func testRemovedSnapshotIgnoresQueuedAlertCallbacks() async {
        let fixture = AlertSubscriptionFixture(isCloud: true)
        defer { fixture.cleanUp() }
        fixture.snapshot.latestRawRecord = fixture.record(isCloud: true)
        fixture.load()
        await fixture.settle()
        fixture.assertFiring(true)

        fixture.deliverUntriggeredCallbacks(for: fixture.mac!.value)
        fixture.load([])
        await fixture.settle()

        fixture.assertFiring(true)
    }
}

@MainActor private final class AlertSubscriptionFixture {
    let luid = UUID().uuidString.luid
    let mac: MACIdentifier?
    let sensor: RuuviTagSensorStruct
    let snapshot: RuuviTagCardSnapshot
    let coordinator: RuuviTagServiceCoordinator
    let notifier: RuuviNotifier
    let alerts: RuuviServiceAlert
    let types: [AlertType] = [
        .aqi(lower: 99, upper: 100),
        .carbonDioxide(lower: 0, upper: 400),
        .pMatter25(lower: 0, upper: 5),
    ]

    init(isCloud: Bool, hasMAC: Bool = true) {
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
        mac = hasMAC ? String(suffix).mac : nil
        sensor = RuuviTagSensorStruct(
            version: 225, firmwareVersion: nil, luid: luid, macId: mac,
            serviceUUID: "test-local-service", isConnectable: true, name: "Test Air",
            isClaimed: false, isOwner: true, owner: nil, ownersPlan: nil,
            isCloudSensor: false, canShare: false, sharedTo: [], maxHistoryDays: nil
        )
        snapshot = RuuviTagCardSnapshot.create(
            id: sensor.id, name: sensor.name, luid: luid, mac: mac,
            serviceUUID: sensor.serviceUUID, isCloud: isCloud, isOwner: true,
            isConnectable: true, version: sensor.version
        )
        let resolver = AppAssembly.shared.assembler.resolver
        notifier = resolver.resolve(RuuviNotifier.self)!
        alerts = resolver.resolve(RuuviServiceAlert.self)!
        coordinator = RuuviTagCoordinatorFactory.createCoordinator(
            pushNotificationsManager: AlertTestPushNotifications()
        )
        // Observe the real service's snapshot without presenter-driven refresh loops.
        coordinator.services.alert.delegate = nil
        // Persist local settings for both identities without making cloud requests.
        types.forEach { alerts.register(type: $0, ruuviTag: sensor) }
    }

    func cleanUp() {
        types.forEach { alerts.remove(type: $0, ruuviTag: sensor) }
    }

    func load(_ snapshots: [RuuviTagCardSnapshot]? = nil) {
        coordinator.sensorDataService(
            coordinator.services.data, didUpdateSnapshots: snapshots ?? [snapshot], withAnimation: false
        )
    }

    func update() {
        coordinator.sensorDataService(
            coordinator.services.data, didUpdateSnapshot: snapshot, invalidateLayout: false
        )
    }

    func process() {
        coordinator.services.alert.triggerAlertsIfNeeded(for: snapshot)
    }

    func deliverUntriggeredCallbacks(for identifier: String) {
        for type in types {
            coordinator.services.alert.ruuvi(
                notifier: notifier, alertType: type, isTriggered: false, for: identifier
            )
        }
    }

    func record(isCloud: Bool, safe: Bool = false) -> RuuviTagSensorRecord {
        RuuviTagSensorRecordStruct(
            luid: isCloud ? nil : luid, date: Date(), source: isCloud ? .ruuviNetwork : .advertisement,
            macId: mac, rssi: nil, version: 225, temperature: nil, humidity: nil, pressure: nil,
            acceleration: nil, voltage: nil, movementCounter: nil,
            measurementSequenceNumber: nil, txPower: nil, pm1: nil, pm25: safe ? 0 : 30,
            pm4: nil, pm10: nil, co2: safe ? 400 : 1000, voc: nil, nox: nil, luminance: nil,
            dbaInstant: nil, dbaAvg: nil, dbaPeak: nil,
            temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0
        )
    }

    func assertFiring(_ expected: Bool, file: StaticString = #filePath, line: UInt = #line) {
        for type in types {
            XCTAssertEqual(snapshot.getAlertConfig(for: type)?.isFiring, expected,
                           type.rawValue, file: file, line: line)
        }
    }

    func settle() async {
        try? await Task.sleep(nanoseconds: 350_000_000)
    }
}

private final class AlertTestPushNotifications: RuuviCorePN {
    var pnTokenData: Data?
    var fcmToken: String?
    var fcmTokenId: Int?
    var fcmTokenLastRefreshed: Date?

    func registerForRemoteNotifications() {}

    func getRemoteNotificationsAuthorizationStatus(completion: @escaping (PNAuthorizationStatus) -> Void) {
        completion(.denied)
    }
}
