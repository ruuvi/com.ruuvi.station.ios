import Foundation
import RuuviCloud
import RuuviContext
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviRepository
import RuuviService
import RuuviStorage
#if SWIFT_PACKAGE
    import RuuviContextSQLite
    import RuuviLocalUserDefaults
    import RuuviPersistenceSQLite
    import RuuviPoolCoordinator
    import RuuviRepositoryCoordinator
    import RuuviStorageCoordinator
    import RuuviServiceCloudSync
    import RuuviServiceAlert
#endif

@MainActor final class CloudSyncFixture {
    private let suite = "CloudSyncAlertsTests." + UUID().uuidString
    private let defaults: UserDefaults
    let cloud = CloudSpy()
    let directory: URL
    let persistence: RuuviPersistenceSQLite
    let pool: RuuviPool
    let storage: RuuviStorage
    let repository: RuuviRepository
    let ids: RuuviLocalIDs
    var settings: RuuviLocalSettings
    let syncState: RuuviLocalSyncState
    let alerts: RuuviServiceAlertImpl
    let service: RuuviServiceCloudSyncImpl
    var sensor: RuuviTagSensorStruct
    private let savedCloudMode: Bool
    private let savedIsSyncing: Bool
    private let savedSyncDate: Date?
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        defaults = UserDefaults(suiteName: suite)!
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("sync.sqlite"))
        persistence = RuuviPersistenceSQLite(context: context)
        let local = RuuviLocalFactoryUserDefaults()
        ids = local.createLocalIDs()
        settings = local.createLocalSettings()
        syncState = local.createLocalSyncState()
        savedCloudMode = settings.cloudModeEnabled
        savedIsSyncing = settings.isSyncing
        savedSyncDate = syncState.getSyncDate()
        settings.cloudModeEnabled = false
        pool = RuuviPoolFactoryCoordinator().create(
            sqlite: persistence, idPersistence: ids, settings: settings,
            connectionPersistence: local.createLocalConnections())
        storage = RuuviStorageFactoryCoordinator().create(sqlite: persistence)
        repository = RuuviRepositoryFactoryCoordinator().create(pool: pool, storage: storage)
        alerts = RuuviServiceAlertImpl(cloud: cloud, localIDs: ids, ruuviLocalSettings: settings, defaults: defaults)
        service = RuuviServiceCloudSyncImpl(
            ruuviStorage: storage, ruuviCloud: cloud, ruuviPool: pool, ruuviLocalSettings: settings,
            ruuviLocalSyncState: syncState, ruuviLocalImages: local.createLocalImages(), ruuviRepository: repository,
            ruuviLocalIDs: ids, ruuviAlertService: alerts)
        let bytes = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(12)
        let mac = stride(from: 0, to: 12, by: 2).map { offset in
            let start = bytes.index(bytes.startIndex, offsetBy: offset)
            return String(bytes[start..<bytes.index(start, offsetBy: 2)])
        }.joined(separator: ":")
        sensor = RuuviTagSensorStruct(
            version: 5, firmwareVersion: nil, luid: UUID().uuidString.luid, macId: mac.mac,
            serviceUUID: nil, isConnectable: true, name: "Local sensor", isClaimed: true, isOwner: true,
            owner: "test@example.com", ownersPlan: "Free", isCloudSensor: true,
            canShare: false, sharedTo: [], maxHistoryDays: 10)
        ids.set(luid: sensor.luid!, for: sensor.macId!)
        ids.set(mac: sensor.macId!, for: sensor.luid!)
        cloud.onDense = { [] }
        cloud.onHistory = { _, _ in [] }
        cloud.onSettings = { SyncSettingsFixture(userSettings: []) }
    }

    func cloudSensor(name: String = "Cloud sensor", updated: Date? = nil, days: Int = 10, plan: String = "Free")
        -> CloudSensorStruct
    {
        CloudSensorStruct(
            id: sensor.macId!.value, serviceUUID: nil, name: name, isClaimed: true, isOwner: true,
            owner: "test@example.com", ownersPlan: plan, picture: nil, offsetTemperature: nil,
            offsetHumidity: nil, offsetPressure: nil, isCloudSensor: true, canShare: false,
            sharedTo: [], maxHistoryDays: days, lastUpdated: updated)
    }

    func dense(
        _ cloudSensor: CloudSensor? = nil, record: RuuviTagSensorRecord? = nil,
        display: RuuviCloudSensorSettings? = nil
    ) -> RuuviCloudSensorDense {
        RuuviCloudSensorDense(
            sensor: cloudSensor ?? self.cloudSensor(), record: record,
            alerts: CloudSensorAlertsFixture(sensor: sensor.macId?.value, alerts: []),
            subscription: nil, settings: display)
    }

    func record(seconds: Double = 0) -> RuuviTagSensorRecordStruct {
        RuuviTagSensorRecordStruct(
            luid: nil, date: date.addingTimeInterval(seconds), source: .ruuviNetwork, macId: sensor.macId, rssi: -50,
            version: 5,
            temperature: .init(value: 20, unit: .celsius), humidity: nil, pressure: nil, acceleration: nil,
            voltage: nil, movementCounter: nil, measurementSequenceNumber: nil, txPower: nil,
            pm1: nil, pm25: nil, pm4: nil, pm10: nil, co2: nil, voc: nil, nox: nil, luminance: nil,
            dbaInstant: nil, dbaAvg: nil, dbaPeak: nil, temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0)
    }

    func close() {
        defaults.removePersistentDomain(forName: suite)
        UserDefaults.standard.removeObject(forKey: sensor.luid!.value)
        UserDefaults.standard.removeObject(forKey: sensor.macId!.value)
        settings.cloudModeEnabled = savedCloudMode
        settings.isSyncing = savedIsSyncing
        syncState.setSyncDate(savedSyncDate)
        syncState.setSyncDate(nil, for: sensor.macId)
        syncState.setDownloadFullHistory(for: sensor.macId, downloadFull: nil)
        try? persistence.database.dbPool.close()
        try? FileManager.default.removeItem(at: directory)
    }
}

struct SyncSettingsFixture: RuuviCloudSettings {
    let userSettings: [RuuviUserSetting]
}
