import BTKit
import Foundation
import RuuviLocal
import RuuviNotification
import RuuviNotifier
import RuuviOntology
import RuuviReactor
import XCTest
@testable import RuuviDaemon
@testable import station

@MainActor final class HeartbeatFixture {
    let measurements = MeasurementFixture()
    let pool = AppPoolSpy()
    let reactor = AppTestReactor()
    let connections = CoordinatorConnectionsSpy()
    let transport = HeartbeatTransportSpy()
    let notifications = HeartbeatNotificationSpy()
    let notifier = HeartbeatNotifierSpy()
    let center = NotificationCenter()
    let suite = "HeartbeatTests." + UUID().uuidString
    let defaults: UserDefaults
    let cache: WidgetSensorCache
    var sensor: RuuviTagSensorStruct
    lazy var worker = RuuviTagHeartbeatDaemonBTKit(
        background: BTKit.background,
        localNotificationsManager: notifications, connectionPersistence: connections, ruuviPool: pool,
        ruuviStorage: measurements.storage, ruuviReactor: reactor, alertService: measurements.alerts,
        alertHandler: notifier, settings: measurements.settings, titles: HeartbeatTitles(),
        transport: transport, widgetCache: cache, notificationCenter: center)
    init() {
        defaults = UserDefaults(suiteName: suite)!
        cache = WidgetSensorCache(userDefaults: defaults)
        sensor = measurements.sensor
        sensor.version = 5
        sensor.macId = "AA:BB:CC:DD:EE:FF".mac
        sensor.serviceUUID = "FEAA"
        measurements.settings.appIsOnForeground = true
        measurements.settings.saveHeartbeats = true
        measurements.settings.saveHeartbeatsForegroundIntervalSeconds = 0
        measurements.settings.saveHeartbeatsIntervalMinutes = 1
        measurements.storage.settingsBySensor = [:]
        pool.allowRecordWrites = true
    }
    func start(keepConnection: Bool = true) async {
        if keepConnection { connections.setKeepConnection(true, for: sensor.luid!) }
        worker.start()
        await waitForAppState("heartbeat reactor") { reactor.sensors.count == 1 }
        send(.initial([sensor.any]))
        if keepConnection { await waitForAppState("heartbeat connection") { !transport.connections.isEmpty } }
        await flushAppBindings(); await flushAppBindings()
    }
    func send(_ change: RuuviReactorChange<AnyRuuviTagSensor>) {
        Array(reactor.sensors.values).forEach { $0(change) }
    }
    func packet(sequence: Int? = 1) -> RuuviTag {
        .v5(
            .init(
                uuid: sensor.luid!.value, rssi: -55, isConnectable: true, version: 5,
                humidity: 50, temperature: 20, pressure: 1000, accelerationX: 0.1, accelerationY: -0.2,
                accelerationZ: 1, voltage: 3, movementCounter: 12, measurementSequenceNumber: sequence,
                txPower: 4, mac: sensor.macId!.value))
    }
    func backgroundPacket(sequence: Int = 1) -> RuuviTag {
        .vC5(
            .init(
                uuid: sensor.luid!.value, serviceUUID: sensor.serviceUUID, rssi: -55,
                isConnectable: true, version: 197, humidity: 50, temperature: 20, pressure: 1000,
                voltage: 3, movementCounter: 12, measurementSequenceNumber: sequence, txPower: 4,
                mac: sensor.macId!.value))
    }
    func emit(_ packet: RuuviTag? = nil) { transport.connections.last?.heartbeat(packet ?? self.packet()) }
    func calibration(_ offset: Double) -> SensorSettings {
        SensorSettingsStruct(
            luid: sensor.luid, macId: sensor.macId, temperatureOffset: offset,
            humidityOffset: nil, pressureOffset: nil)
    }
    func cleanup() {
        worker.stop()
        DispatchQueue.main.async { [defaults, suite] in defaults.removePersistentDomain(forName: suite) }
        measurements.cleanup()
    }
}

private struct HeartbeatTitles: RuuviTagHeartbeatDaemonTitles {
    let didConnect = "Sensor connected"
    let didDisconnect = "Sensor disconnected"
}

final class HeartbeatNotificationSpy: RuuviNotificationLocal {
    var connected = [(String, String)]()
    var disconnected = [(String, String)]()
    func setup(disableTitle: String, muteTitle: String, output: RuuviNotificationLocalOutput?) {}
    func showDidConnect(uuid: String, title: String) { connected.append((uuid, title)) }
    func showDidDisconnect(uuid: String, title: String) { disconnected.append((uuid, title)) }
    func notifyDidMove(for uuid: String, counter: Int, title: String) {}
    func notify(_ reason: LowHighNotificationReason, _ type: AlertType, for uuid: String, title: String) {}
}

final class HeartbeatNotifierSpy: RuuviNotifier {
    var records = [AnyRuuviTagSensorRecord]()
    var triggers = [Bool]()
    func process(record: RuuviTagSensorRecord, trigger: Bool) { records.append(record.any); triggers.append(trigger) }
    func processNetwork(record: RuuviTagSensorRecord, trigger: Bool, for identifier: MACIdentifier) {}
    func subscribe<T: RuuviNotifierObserver>(_ observer: T, to uuid: String) {}
    func isSubscribed<T: RuuviNotifierObserver>(_ observer: T, to uuid: String) -> Bool { false }
    func clearMovementHysteresis(for uuid: String) {}
}
