import BTKit
import CoreBluetooth
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviReactor
import RuuviService
import XCTest
@testable import RuuviDaemon
@testable import station

@MainActor final class AdvertisementFixture {
    let measurements = MeasurementFixture()
    let pool = AppPoolSpy()
    let reactor = AppTestReactor()
    let sync = AppSyncStateSpy()
    let gatt = AdvertisementGattSpy()
    let center = NotificationCenter()
    let suite = "AdvertisementTests." + UUID().uuidString
    let defaults: UserDefaults
    let cache: WidgetSensorCache
    var sensor: RuuviTagSensorStruct
    var scans = [(String, (RuuviTag) -> Void)]()
    var cancellations = [String]()
    lazy var worker = RuuviTagAdvertisementDaemonBTKit(
        ruuviPool: pool, ruuviStorage: measurements.storage, ruuviReactor: reactor,
        foreground: BTKit.foreground, settings: measurements.settings, flags: measurements.flags,
        localSyncState: sync, gattService: gatt, widgetCache: cache, notificationCenter: center,
        observeAdvertisement: { [weak self] uuid, callback in
            self?.scans.append((uuid, callback))
            return { [weak self] in self?.cancellations.append(uuid) }
        })
    init() {
        defaults = UserDefaults(suiteName: suite)!
        cache = WidgetSensorCache(userDefaults: defaults)
        sensor = measurements.sensor
        sensor.version = 5
        sensor.macId = "AA:BB:CC:DD:EE:FF".mac
        measurements.settings.appIsOnForeground = true
        measurements.settings.isAdvertisementDaemonOn = true
        measurements.settings.advertisementDaemonIntervalMinutes = 1
        measurements.storage.useLatestOverride = true
        measurements.storage.settingsBySensor = [:]
        pool.allowRecordWrites = true
        pool.beforeCreateLatest = { [weak self] in
            self?.measurements.storage.latestOverride = self?.pool.createdLatest.last
        }
        pool.beforeUpdateLatest = { [weak self] in
            self?.measurements.storage.latestOverride = self?.pool.updatedLatest.last
        }
    }
    func start(_ sensors: [AnyRuuviTagSensor]? = nil) async {
        let expectedScans = scans.count + 1
        worker.start()
        await waitForAppState("advertisement reactor") { reactor.sensors.count == 1 }
        send(.initial(sensors ?? [sensor.any]))
        await flushAppBindings(); await flushAppBindings()
        if sensors == nil { await waitForAppState("advertisement scan") { scans.count == expectedScans } }
    }
    func send(_ change: RuuviReactorChange<AnyRuuviTagSensor>) {
        Array(reactor.sensors.values).forEach { $0(change) }
    }
    func emit(_ record: RuuviTag) { scans.last?.1(record) }
    func packet(sequence: Int? = 1) -> RuuviTag {
        .v5(
            .init(
                uuid: sensor.luid!.value, rssi: -55, isConnectable: true, version: 5,
                humidity: 50, temperature: 20, pressure: 1000, accelerationX: 0.1,
                accelerationY: -0.2, accelerationZ: 1, voltage: 3, movementCounter: 12,
                measurementSequenceNumber: sequence, txPower: 4, mac: sensor.macId!.value))
    }
    func airPacket(sequence: UInt8 = 1) throws -> RuuviTag {
        var bytes = [UInt8](repeating: 0, count: 22)
        bytes[0] = 0x99; bytes[1] = 0x04; bytes[2] = 0x06
        bytes[17] = sequence
        bytes[19] = 0xDD; bytes[20] = 0xEE; bytes[21] = 0xFF
        return try XCTUnwrap(
            RuuviDecoderiOS().decodeAdvertisement(
                uuid: sensor.luid!.value, rssi: -55,
                advertisementData: [
                    CBAdvertisementDataManufacturerDataKey: Data(bytes), CBAdvertisementDataIsConnectable: true,
                ],
                isConnected: false, supportsExtendedAdv: false)?.ruuvi?.tag)
    }
    func cleanup() {
        worker.stop()
        DispatchQueue.main.async { [defaults, suite] in defaults.removePersistentDomain(forName: suite) }
        measurements.cleanup()
    }
}

@MainActor final class AdvertisementGattSpy: GATTService {
    struct Request {
        let uuid: String
        let mac: String?
        let firmware: Int
        let from: Date
        let settings: SensorSettings?
        let timeouts: GATTServiceTimeouts
    }
    var requests = [Request]()
    var stops = [String]()
    var stopFailure: RuuviServiceError?
    var globallySyncing = false
    var syncingIDs = Set<String>()
    var result = true
    var failure: RuuviServiceError?
    var beforeSync: (() async -> Void)?
    func isSyncingLogs() -> Bool { globallySyncing }
    func isSyncingLogs(with uuid: String) -> Bool { syncingIDs.contains(uuid) }
    func syncLogs(
        uuid: String, mac: String?, firmware: Int, from: Date, settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?, timeouts: GATTServiceTimeouts
    ) async throws(RuuviServiceError) -> Bool {
        requests.append(
            .init(uuid: uuid, mac: mac, firmware: firmware, from: from, settings: settings, timeouts: timeouts))
        await beforeSync?()
        if let failure { throw failure }
        return result
    }
    func stopGattSync(for uuid: String) async throws(RuuviServiceError) -> Bool {
        stops.append(uuid)
        if let stopFailure { throw stopFailure }
        return true
    }
}
