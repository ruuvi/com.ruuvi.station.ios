import BTKit
import Foundation
import RuuviLocal
import RuuviNotifier
import RuuviOntology
@testable import station

@MainActor final class CoordinatorFixture {
    let data = SensorDataFixture()
    let connections = CoordinatorConnectionsSpy()
    let sync = AppSyncStateSpy()
    let notifier = CoordinatorNotifierSpy()
    let user = DefaultsUserSpy()
    let daemon = SignInDaemonSpy()
    let auth = AccountAuthSpy()
    let push = AccountPushSpy()
    let notifications = AccountNotificationSpy()
    let cloud: RuuviCloudService
    let alerts: RuuviTagAlertService
    let connection: RuuviTagConnectionService
    let coordinator: RuuviTagServiceCoordinator
    let manager: RuuviTagServiceCoordinatorManager
    init() {
        cloud = RuuviCloudService(
            cloudSyncDaemon: daemon, cloudNotificationService: notifications, authService: auth,
            ruuviUser: user, settings: data.measurements.settings, pnManager: push)
        alerts = RuuviTagAlertService(
            alertService: data.measurements.alerts, alertHandler: notifier,
            settings: data.measurements.settings, pushNotificationsManager: push)
        connection = RuuviTagConnectionService(
            foreground: BTKit.foreground, background: BTKit.background,
            connectionPersistence: connections, localSyncState: sync)
        coordinator = RuuviTagServiceCoordinator(
            dataService: data.service, cloudService: cloud, alertService: alerts, connectionService: connection)
        manager = RuuviTagServiceCoordinatorManager(coordinator: coordinator)
    }
    func start(_ sensors: [RuuviTagSensorStruct]) async {
        coordinator.start()
        data.send(.initial(sensors.map(\.any)))
        await waitForAppState("coordinator snapshots") { coordinator.getAllSnapshots().count == sensors.count }
        await flushAppBindings()
    }
    func cleanup() { coordinator.stop(); data.cleanup() }
}

final class CoordinatorConnectionsSpy: RuuviLocalConnections {
    private let lock = NSLock()
    private var kept = [AnyLocalIdentifier]()
    private var recordedChanges = [(String, Bool)]()
    var changes: [(String, Bool)] { lock.withLock { recordedChanges } }
    var keepConnectionUUIDs: [AnyLocalIdentifier] { lock.withLock { kept } }
    func keepConnection(to luid: LocalIdentifier) -> Bool { lock.withLock { kept.contains(luid.any) } }
    func setKeepConnection(_ value: Bool, for luid: LocalIdentifier) {
        lock.withLock {
            recordedChanges.append((luid.value, value))
            kept.removeAll { $0 == luid.any }
            if value { kept.append(luid.any) }
        }
    }
    func unpairAllConnection() { lock.withLock { kept.removeAll() } }
}

final class AppSyncStateSpy: RuuviLocalSyncState {
    private let lock = NSLock()
    private var statuses = [String: NetworkSyncStatus]()
    private var dates = [String: Date]()
    private var flags = [String: Bool]()
    private func key(_ prefix: String, _ id: MACIdentifier?) -> String { prefix + (id?.value ?? "all") }
    private func setDate(_ date: Date?, _ key: String) { lock.withLock { dates[key] = date } }
    private func date(_ key: String) -> Date? { lock.withLock { dates[key] } }
    private func setFlag(_ value: Bool?, _ key: String) { lock.withLock { flags[key] = value } }
    private func flag(_ key: String) -> Bool? { lock.withLock { flags[key] } }
    func setSyncStatus(_ status: NetworkSyncStatus) { lock.withLock { statuses["all"] = status } }
    func setSyncStatusLatestRecord(_ status: NetworkSyncStatus, for macId: MACIdentifier) {
        lock.withLock { statuses[key("latest", macId)] = status }
    }
    func getSyncStatusLatestRecord(for macId: MACIdentifier) -> NetworkSyncStatus {
        lock.withLock { statuses[key("latest", macId)] ?? .none }
    }
    func setSyncStatusHistory(_ status: NetworkSyncStatus, for macId: MACIdentifier?) {
        lock.withLock { statuses[key("history", macId)] = status }
    }
    func setSyncDate(_ date: Date?, for macId: MACIdentifier?) { setDate(date, key("sync", macId)) }
    func getSyncDate(for macId: MACIdentifier?) -> Date? { date(key("sync", macId)) }
    func setGattSyncDate(_ date: Date?, for macId: MACIdentifier?) { setDate(date, key("gatt", macId)) }
    func getGattSyncDate(for macId: MACIdentifier?) -> Date? { date(key("gatt", macId)) }
    func setAutoGattSyncAttemptDate(_ date: Date?, for macId: MACIdentifier?) { setDate(date, key("attempt", macId)) }
    func getAutoGattSyncAttemptDate(for macId: MACIdentifier?) -> Date? { date(key("attempt", macId)) }
    func setAutoGattSyncSuppressed(_ value: Bool, for macId: MACIdentifier?) {
        setFlag(value, key("suppressed", macId))
    }
    func isAutoGattSyncSuppressed(for macId: MACIdentifier?) -> Bool { flag(key("suppressed", macId)) ?? false }
    func resetAutoGattSyncSuppression() {
        lock.withLock { flags = flags.filter { !$0.key.hasPrefix("suppressed") } }
    }
    func setHasLoggedFirstAutoSyncGattHistoryForRuuviAir(_ value: Bool, for macId: MACIdentifier?) {
        setFlag(value, key("logged", macId))
    }
    func hasLoggedFirstAutoSyncGattHistoryForRuuviAir(for macId: MACIdentifier?) -> Bool {
        flag(key("logged", macId)) ?? false
    }
    func setSyncDate(_ date: Date?) { setDate(date, "global") }
    func getSyncDate() -> Date? { date("global") }
    func setDownloadFullHistory(for macId: MACIdentifier?, downloadFull: Bool?) {
        setFlag(downloadFull, key("download", macId))
    }
    func downloadFullHistory(for macId: MACIdentifier?) -> Bool? { flag(key("download", macId)) }
}

final class CoordinatorNotifierSpy: RuuviNotifier {
    private final class Observer {
        weak var value: RuuviNotifierObserver?; init(_ value: RuuviNotifierObserver) { self.value = value }
    }
    private let lock = NSLock()
    private var observers = [String: [Observer]]()
    private var processed = [(String?, Bool)]()
    private var cleared = [String]()
    var records: [(String?, Bool)] { lock.withLock { processed } }
    var clearedMovement: [String] { lock.withLock { cleared } }
    func process(record: RuuviTagSensorRecord, trigger: Bool) {
        lock.withLock { processed.append((record.luid?.value, trigger)) }
    }
    func processNetwork(record: RuuviTagSensorRecord, trigger: Bool, for identifier: MACIdentifier) {
        lock.withLock { processed.append((identifier.value, trigger)) }
    }
    func subscribe<T: RuuviNotifierObserver>(_ observer: T, to uuid: String) {
        lock.withLock { observers[uuid, default: []].append(Observer(observer)) }
    }
    func isSubscribed<T: RuuviNotifierObserver>(_ observer: T, to uuid: String) -> Bool {
        lock.withLock { observers[uuid]?.contains { $0.value === observer } ?? false }
    }
    func clearMovementHysteresis(for uuid: String) { lock.withLock { cleared.append(uuid) } }
}
