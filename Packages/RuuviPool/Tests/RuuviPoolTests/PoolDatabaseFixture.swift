import Foundation
import RuuviContext
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
#if SWIFT_PACKAGE
    import RuuviContextSQLite
    import RuuviLocalUserDefaults
    import RuuviPersistenceSQLite
    import RuuviPoolCoordinator
#endif

final class PoolDatabaseFixture {
    let directory: URL
    let context: SQLiteContext
    let persistence: RuuviPersistenceSQLite
    let pool: RuuviPool
    let ids = PoolIdentifiers()
    let connections = PoolConnections()
    let luid = UUID().uuidString.luid
    let mac = "AA:BB:CC:DD:EE:FF".mac
    let date = Date(timeIntervalSince1970: 1_700_000_000)

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("pool.sqlite"))
        persistence = RuuviPersistenceSQLite(context: context)
        pool = RuuviPoolFactoryCoordinator().create(
            sqlite: persistence, idPersistence: ids,
            settings: RuuviLocalFactoryUserDefaults().createLocalSettings(), connectionPersistence: connections)
    }

    func close() {
        try? context.database.dbPool.close()
        try? FileManager.default.removeItem(at: directory)
    }

    func sensor() -> RuuviTagSensorStruct {
        .init(
            version: 5, firmwareVersion: nil, luid: luid, macId: mac, serviceUUID: nil,
            isConnectable: true, name: "Room", isClaimed: false, isOwner: true, owner: nil,
            ownersPlan: nil, isCloudSensor: false, canShare: false, sharedTo: [], maxHistoryDays: nil)
    }

    func record() -> RuuviTagSensorRecordStruct {
        .init(
            luid: luid, date: date, source: .advertisement, macId: mac,
            rssi: nil, version: 5, temperature: .init(value: 21, unit: .celsius), humidity: nil,
            pressure: nil, acceleration: nil, voltage: nil, movementCounter: nil, measurementSequenceNumber: nil,
            txPower: nil, pm1: nil, pm25: nil, pm4: nil, pm10: nil, co2: nil, voc: nil, nox: nil,
            luminance: nil, dbaInstant: nil, dbaAvg: nil, dbaPeak: nil,
            temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0)
    }
}

final class PoolIdentifiers: RuuviLocalIDs {
    var macs = [String: String]()
    var luids = [String: String]()
    var writes = 0
    func mac(for luid: LocalIdentifier) -> MACIdentifier? { macs[luid.value]?.mac }
    func luid(for mac: MACIdentifier) -> LocalIdentifier? { luids[mac.value]?.luid }
    func set(mac: MACIdentifier, for luid: LocalIdentifier) { macs[luid.value] = mac.value; writes += 1 }
    func set(luid: LocalIdentifier, for mac: MACIdentifier) { luids[mac.value] = luid.value; writes += 1 }
    func extendedLuid(for mac: MACIdentifier) -> LocalIdentifier? { nil }
    func set(extendedLuid: LocalIdentifier, for mac: MACIdentifier) {}
    func fullMac(for mac: MACIdentifier) -> MACIdentifier? { nil }
    func originalMac(for fullMac: MACIdentifier) -> MACIdentifier? { nil }
    func set(fullMac: MACIdentifier, for mac: MACIdentifier) {}
    func removeFullMac(for mac: MACIdentifier) {}
}

final class PoolConnections: RuuviLocalConnections {
    var paired = Set<String>()
    var keepConnectionUUIDs: [AnyLocalIdentifier] { paired.map { $0.luid.any } }
    func keepConnection(to luid: LocalIdentifier) -> Bool { paired.contains(luid.value) }
    func setKeepConnection(_ value: Bool, for luid: LocalIdentifier) {
        if value { paired.insert(luid.value) } else { paired.remove(luid.value) }
    }
    func unpairAllConnection() { paired.removeAll() }
}
