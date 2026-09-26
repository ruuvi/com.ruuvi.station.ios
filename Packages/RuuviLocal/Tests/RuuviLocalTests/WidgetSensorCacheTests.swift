@testable import RuuviLocal
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
