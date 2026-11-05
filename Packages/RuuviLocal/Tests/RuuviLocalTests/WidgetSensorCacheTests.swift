@testable import RuuviLocal
import RuuviOntology
import XCTest

final class WidgetSensorCacheTests: XCTestCase {
    func testCloudUpdateKeepsNewerBluetoothRecord() {
        let suiteName = "WidgetSensorCacheTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let cache = WidgetSensorCache(userDefaults: defaults)

        let bluetoothRecord = makeRecord(date: 2_000, temperature: 22)
        cache.upsert(
            sensorId: "sensor",
            name: "Sensor",
            macId: "AA:BB",
            luid: nil,
            record: bluetoothRecord,
            settings: nil
        )

        cache.upsert(
            sensorId: "sensor",
            name: "Sensor",
            macId: "AA:BB",
            luid: nil,
            record: makeRecord(date: 1_000, temperature: 18, source: "ruuviNetwork"),
            settings: nil
        )
        XCTAssertEqual(cache.snapshot(matching: "sensor")?.record, bluetoothRecord)

        cache.upsert(
            sensorId: "sensor",
            name: "Sensor",
            macId: "AA:BB",
            luid: nil,
            record: makeRecord(date: 2_000, temperature: 20, source: "ruuviNetwork"),
            settings: nil
        )
        XCTAssertEqual(cache.snapshot(matching: "sensor")?.record, bluetoothRecord)

        let newerCloudRecord = makeRecord(date: 3_000, temperature: 24, source: "ruuviNetwork")
        cache.upsert(
            sensorId: "sensor",
            name: "Sensor",
            macId: "AA:BB",
            luid: nil,
            record: newerCloudRecord,
            settings: nil
        )
        XCTAssertEqual(cache.snapshot(matching: "sensor")?.record, newerCloudRecord)

        let correctedCloudRecord = makeRecord(date: 3_000, temperature: 25, source: "ruuviNetwork")
        cache.upsert(
            sensorId: "sensor",
            name: "Sensor",
            macId: "AA:BB",
            luid: nil,
            record: correctedCloudRecord,
            settings: nil
        )
        XCTAssertEqual(cache.snapshot(matching: "sensor")?.record, correctedCloudRecord)
    }

    private func makeRecord(
        date: TimeInterval,
        temperature: Double,
        source: String = "advertisement"
    ) -> WidgetSensorRecordSnapshot {
        WidgetSensorRecordSnapshot(
            date: Date(timeIntervalSince1970: date),
            source: source,
            macId: "AA:BB",
            luid: nil,
            rssi: nil,
            version: 5,
            temperature: temperature,
            humidity: nil,
            pressure: nil,
            accelerationX: nil,
            accelerationY: nil,
            accelerationZ: nil,
            voltage: nil,
            movementCounter: nil,
            measurementSequenceNumber: nil,
            txPower: nil,
            pm1: nil,
            pm25: nil,
            pm4: nil,
            pm10: nil,
            co2: nil,
            voc: nil,
            nox: nil,
            luminance: nil,
            dbaInstant: nil,
            dbaAvg: nil,
            dbaPeak: nil,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil
        )
    }
}

extension WidgetSensorCacheTests {
    func testAppUpdatePreservesNewerReadingsAndPrefersBluetoothAtTheSameTimestamp() throws {
        try withCache { cache, _ in
            let sensor = makeSensor(mac: "AA:BB", luid: "local", name: "Sensor")
            let newest = makeRecord(date: 3000, temperature: 30, source: "ruuviNetwork")
            cache.upsert(sensor: sensor, record: newest, settings: nil)
            cache.upsert(sensor: sensor, record: makeRecord(date: 2000, temperature: 20), settings: nil)
            XCTAssertEqual(cache.snapshot(matching: sensor.id)?.record, newest)
            let bluetooth = makeRecord(date: 3000, temperature: 31)
            cache.upsert(sensor: sensor, record: bluetooth, settings: nil)
            XCTAssertEqual(cache.snapshot(matching: sensor.id)?.record, bluetooth)
            cache.upsert(sensor: sensor, record: newest, settings: nil)
            XCTAssertEqual(cache.snapshot(matching: sensor.id)?.record, bluetooth)
            cache.upsert(sensor: sensor, record: nil, settings: nil)
            XCTAssertEqual(cache.snapshot(matching: sensor.id)?.record, bluetooth)
        }
    }

    func testSyncingSensorListPreservesReadingsAndSettingsAcrossIdentityChangesAndPrunesRemovedSensors() throws {
        try withCache { cache, _ in
            let local = makeSensor(mac: nil, luid: "local", name: "")
            let paired = makeSensor(mac: "AA:BB", luid: "local", name: "Paired")
            let extra = makeSensor(mac: "CC:DD", luid: nil, name: "")
            let record = makeRecord(date: 2000, temperature: 22)
            let settings = SensorSettingsStruct(
                luid: "local".luid, macId: nil, temperatureOffset: 1, humidityOffset: 2, pressureOffset: 3,
                displayOrder: ["temperature", "humidity"], defaultDisplayOrder: false)
            cache.upsert(sensor: local, record: record, settings: settings)
            XCTAssertEqual(cache.snapshot(matching: "local")?.name, "local")
            cache.upsert(sensor: paired, record: nil, settings: nil)
            XCTAssertEqual(cache.loadAll().count, 1)
            XCTAssertEqual(cache.snapshot(matching: "local")?.id, "AA:BB")
            XCTAssertEqual(cache.snapshot(matching: "AA:BB")?.record, record)
            cache.syncSensors([extra, paired]) { $0.id == extra.id ? settings : nil }
            XCTAssertEqual(cache.loadAll().map(\.id), [extra.id, paired.id])
            XCTAssertEqual(cache.snapshot(matching: extra.id)?.name, extra.id)
            XCTAssertEqual(cache.snapshot(matching: paired.id)?.record, record)
            XCTAssertEqual(cache.snapshot(matching: paired.id)?.settings?.displayOrder, settings.displayOrder)
            XCTAssertEqual(cache.snapshot(matching: extra.id)?.settings?.temperatureOffset, 1)
            cache.syncSensors([paired])
            XCTAssertNil(cache.snapshot(matching: extra.id))
            cache.prune(keeping: ["local"])
            XCTAssertEqual(cache.loadAll().count, 1)
            cache.prune(keeping: [])
            XCTAssertTrue(cache.loadAll().isEmpty)
        }
    }

    func testCloudSettingsMergePreservesLocalVisibilityAndUpdatesProvidedValues() throws {
        try withCache { cache, defaults in
            let local = WidgetSensorSettingsSnapshot(
                temperatureOffset: 1, humidityOffset: 2, pressureOffset: 3,
                displayOrder: ["temperature"], defaultDisplayOrder: false)
            cache.upsert(sensorId: "sensor", name: "", macId: "AA:BB", luid: "local", record: nil, settings: local)
            XCTAssertEqual(cache.snapshot(matching: "sensor")?.name, "sensor")
            cache.upsert(
                sensorId: "sensor", name: "Renamed", macId: nil, luid: nil,
                record: makeRecord(date: 3000, temperature: 30),
                settings: .init(
                    temperatureOffset: nil, humidityOffset: 4, pressureOffset: 5))
            let restored = try XCTUnwrap(WidgetSensorCache(userDefaults: defaults).snapshot(matching: "local"))
            XCTAssertEqual(restored.name, "Renamed")
            XCTAssertEqual(restored.macId, "AA:BB")
            XCTAssertNil(restored.settings?.temperatureOffset)
            XCTAssertEqual(restored.settings?.humidityOffset, 4)
            XCTAssertEqual(restored.settings?.displayOrder, ["temperature"])
            XCTAssertEqual(restored.settings?.defaultDisplayOrder, false)
            cache.upsert(
                sensorId: "sensor", name: "Renamed", macId: "CC:DD", luid: "new-local", record: nil,
                settings: .init(
                    temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0,
                    displayOrder: ["humidity"], defaultDisplayOrder: true))
            XCTAssertEqual(cache.snapshot(matching: "new-local")?.settings?.displayOrder, ["humidity"])
            XCTAssertEqual(cache.snapshot(matching: "CC:DD")?.settings?.defaultDisplayOrder, true)
            XCTAssertNil(cache.snapshot(matching: "AA:BB"))
            cache.prune(keeping: ["CC:DD"])
            XCTAssertEqual(cache.loadAll().count, 1)
            cache.prune(keeping: ["sensor"])
            XCTAssertEqual(cache.loadAll().count, 1)
        }
    }

    func testUnavailableCorruptedAndUnencodableStorageDoesNotCrashOrDestroyLastValidCache() throws {
        let sensor = makeSensor(mac: "AA:BB", luid: nil, name: "Sensor")
        let unavailable = WidgetSensorCache(userDefaults: nil)
        unavailable.upsert(sensor: sensor, record: nil, settings: nil)
        unavailable.syncSensors([sensor])
        unavailable.prune(keeping: [])
        XCTAssertTrue(unavailable.loadAll().isEmpty)
        XCTAssertNil(unavailable.snapshot(matching: sensor.id))
        try withCache { cache, defaults in
            defaults.set(Data("invalid JSON".utf8), forKey: "RuuviWidgetSensorCache.v1")
            XCTAssertTrue(cache.loadAll().isEmpty)
            cache.upsert(sensor: sensor, record: nil, settings: nil)
            let saved = defaults.data(forKey: "RuuviWidgetSensorCache.v1")
            cache.upsert(sensor: sensor, record: makeRecord(date: 3000, temperature: .nan), settings: nil)
            XCTAssertEqual(defaults.data(forKey: "RuuviWidgetSensorCache.v1"), saved)
            XCTAssertNil(cache.snapshot(matching: sensor.id)?.record)
            cache.upsert(sensorId: "sensor-two", name: "Second", macId: nil, luid: nil, record: nil, settings: nil)
            cache.upsert(
                sensorId: "sensor-two", name: "Second", macId: nil, luid: nil, record: nil,
                settings: .init(temperatureOffset: 1, humidityOffset: nil, pressureOffset: nil))
            XCTAssertEqual(cache.snapshot(matching: "sensor-two")?.settings?.temperatureOffset, 1)
        }
    }

    private func makeSensor(mac: String?, luid: String?, name: String) -> AnyRuuviTagSensor {
        RuuviTagSensorStruct(
            version: 5, firmwareVersion: nil, luid: luid?.luid, macId: mac?.mac,
            serviceUUID: nil, isConnectable: true, name: name, isClaimed: false, isOwner: true,
            owner: nil, ownersPlan: nil, isCloudSensor: false, canShare: false,
            sharedTo: [], maxHistoryDays: nil
        ).any
    }

    private func withCache(_ body: (WidgetSensorCache, UserDefaults) throws -> Void) throws {
        let suite = "ruuvi-widget-tests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(WidgetSensorCache(userDefaults: defaults), defaults)
    }
}
