import Foundation
import RuuviOntology

public struct WidgetSensorSettingsSnapshot: Codable, Equatable {
    public var temperatureOffset: Double?
    public var humidityOffset: Double?
    public var pressureOffset: Double?

    public init(
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?
    ) {
        self.temperatureOffset = temperatureOffset
        self.humidityOffset = humidityOffset
        self.pressureOffset = pressureOffset
    }

    public init(settings: SensorSettings) {
        self.temperatureOffset = settings.temperatureOffset
        self.humidityOffset = settings.humidityOffset
        self.pressureOffset = settings.pressureOffset
    }
}

public struct WidgetSensorRecordSnapshot: Codable, Equatable {
    public var date: Date
    public var source: String
    public var macId: String?
    public var luid: String?
    public var rssi: Int?
    public var version: Int
    public var temperature: Double?
    public var humidity: Double?
    public var pressure: Double?
    public var accelerationX: Double?
    public var accelerationY: Double?
    public var accelerationZ: Double?
    public var voltage: Double?
    public var movementCounter: Int?
    public var measurementSequenceNumber: Int?
    public var txPower: Int?
    public var pm1: Double?
    public var pm25: Double?
    public var pm4: Double?
    public var pm10: Double?
    public var co2: Double?
    public var voc: Double?
    public var nox: Double?
    public var luminance: Double?
    public var dbaInstant: Double?
    public var dbaAvg: Double?
    public var dbaPeak: Double?
    public var temperatureOffset: Double?
    public var humidityOffset: Double?
    public var pressureOffset: Double?

    public init(
        date: Date,
        source: String,
        macId: String?,
        luid: String?,
        rssi: Int?,
        version: Int,
        temperature: Double?,
        humidity: Double?,
        pressure: Double?,
        accelerationX: Double?,
        accelerationY: Double?,
        accelerationZ: Double?,
        voltage: Double?,
        movementCounter: Int?,
        measurementSequenceNumber: Int?,
        txPower: Int?,
        pm1: Double?,
        pm25: Double?,
        pm4: Double?,
        pm10: Double?,
        co2: Double?,
        voc: Double?,
        nox: Double?,
        luminance: Double?,
        dbaInstant: Double?,
        dbaAvg: Double?,
        dbaPeak: Double?,
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?
    ) {
        self.date = date
        self.source = source
        self.macId = macId
        self.luid = luid
        self.rssi = rssi
        self.version = version
        self.temperature = temperature
        self.humidity = humidity
        self.pressure = pressure
        self.accelerationX = accelerationX
        self.accelerationY = accelerationY
        self.accelerationZ = accelerationZ
        self.voltage = voltage
        self.movementCounter = movementCounter
        self.measurementSequenceNumber = measurementSequenceNumber
        self.txPower = txPower
        self.pm1 = pm1
        self.pm25 = pm25
        self.pm4 = pm4
        self.pm10 = pm10
        self.co2 = co2
        self.voc = voc
        self.nox = nox
        self.luminance = luminance
        self.dbaInstant = dbaInstant
        self.dbaAvg = dbaAvg
        self.dbaPeak = dbaPeak
        self.temperatureOffset = temperatureOffset
        self.humidityOffset = humidityOffset
        self.pressureOffset = pressureOffset
    }

}

public struct WidgetSensorSnapshot: Codable, Equatable {
    public var id: String
    public var name: String
    public var macId: String?
    public var luid: String?
    public var record: WidgetSensorRecordSnapshot?
    public var settings: WidgetSensorSettingsSnapshot?
    public var updatedAt: Date

    public init(
        id: String,
        name: String,
        macId: String?,
        luid: String?,
        record: WidgetSensorRecordSnapshot?,
        settings: WidgetSensorSettingsSnapshot?,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.macId = macId
        self.luid = luid
        self.record = record
        self.settings = settings
        self.updatedAt = updatedAt
    }

    public func matches(identifier: String) -> Bool {
        if id == identifier { return true }
        if let macId, macId == identifier { return true }
        if let luid, luid == identifier { return true }
        return false
    }

    func matches(sensor: AnyRuuviTagSensor) -> Bool {
        if id == sensor.id { return true }
        if let mac = sensor.macId?.value {
            if id == mac { return true }
            if macId == mac { return true }
        }
        if let luid = sensor.luid?.value {
            if id == luid { return true }
            if self.luid == luid { return true }
        }
        return false
    }
}

public final class WidgetSensorCache {
    public static let appGroupSuiteIdentifier = "group.com.ruuvi.station.widgets"
    private static let storageKey = "RuuviWidgetSensorCache.v1"
    private static let queue = DispatchQueue(label: "Ruuvi.WidgetSensorCache")

    private let userDefaults: UserDefaults?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        userDefaults: UserDefaults? = UserDefaults(suiteName: WidgetSensorCache.appGroupSuiteIdentifier)
    ) {
        self.userDefaults = userDefaults
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func loadAll() -> [WidgetSensorSnapshot] {
        Self.queue.sync {
            loadAllInternal()
        }
    }

    public func snapshot(matching identifier: String) -> WidgetSensorSnapshot? {
        Self.queue.sync {
            loadAllInternal().first { $0.matches(identifier: identifier) }
        }
    }

    public func upsert(
        sensor: AnyRuuviTagSensor,
        record: WidgetSensorRecordSnapshot?,
        settings: SensorSettings?
    ) {
        Self.queue.sync {
            var snapshots = loadAllInternal()
            if let index = snapshots.firstIndex(where: { $0.matches(sensor: sensor) }) {
                var snapshot = snapshots[index]
                snapshot.id = sensor.id
                snapshot.name = sensor.name.isEmpty ? sensor.id : sensor.name
                snapshot.macId = sensor.macId?.value
                snapshot.luid = sensor.luid?.value
                if let record {
                    snapshot.record = record
                }
                if let settings {
                    snapshot.settings = WidgetSensorSettingsSnapshot(settings: settings)
                }
                snapshot.updatedAt = Date()
                snapshots[index] = snapshot
            } else {
                let snapshot = WidgetSensorSnapshot(
                    id: sensor.id,
                    name: sensor.name.isEmpty ? sensor.id : sensor.name,
                    macId: sensor.macId?.value,
                    luid: sensor.luid?.value,
                    record: record,
                    settings: settings.map { WidgetSensorSettingsSnapshot(settings: $0) }
                )
                snapshots.append(snapshot)
            }
            saveInternal(snapshots)
        }
    }

    public func syncSensors(
        _ sensors: [AnyRuuviTagSensor],
        settingsLookup: (AnyRuuviTagSensor) -> SensorSettings? = { _ in nil }
    ) {
        Self.queue.sync {
            let existing = loadAllInternal()
            var results: [WidgetSensorSnapshot] = []
            results.reserveCapacity(sensors.count)
            for sensor in sensors {
                let existingSnapshot = existing.first { $0.matches(sensor: sensor) }
                var snapshot = existingSnapshot ?? WidgetSensorSnapshot(
                    id: sensor.id,
                    name: sensor.name.isEmpty ? sensor.id : sensor.name,
                    macId: sensor.macId?.value,
                    luid: sensor.luid?.value,
                    record: nil,
                    settings: nil
                )
                snapshot.id = sensor.id
                snapshot.name = sensor.name.isEmpty ? sensor.id : sensor.name
                snapshot.macId = sensor.macId?.value
                snapshot.luid = sensor.luid?.value
                if let settings = settingsLookup(sensor) {
                    snapshot.settings = WidgetSensorSettingsSnapshot(settings: settings)
                }
                snapshot.updatedAt = Date()
                results.append(snapshot)
            }
            saveInternal(results)
        }
    }

    public func prune(keeping identifiers: Set<String>) {
        Self.queue.sync {
            let snapshots = loadAllInternal()
            let filtered = snapshots.filter { snapshot in
                if identifiers.contains(snapshot.id) { return true }
                if let macId = snapshot.macId, identifiers.contains(macId) { return true }
                if let luid = snapshot.luid, identifiers.contains(luid) { return true }
                return false
            }
            saveInternal(filtered)
        }
    }

    private func loadAllInternal() -> [WidgetSensorSnapshot] {
        guard let userDefaults else { return [] }
        guard let data = userDefaults.data(forKey: Self.storageKey) else { return [] }
        return (try? decoder.decode([WidgetSensorSnapshot].self, from: data)) ?? []
    }

    private func saveInternal(_ snapshots: [WidgetSensorSnapshot]) {
        guard let userDefaults else { return }
        guard let data = try? encoder.encode(snapshots) else { return }
        userDefaults.set(data, forKey: Self.storageKey)
    }
}
