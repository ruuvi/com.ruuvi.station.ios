import BTKit
import Foundation
import Humidity
@testable import RuuviOntology
import XCTest

final class SensorRecordTests: XCTestCase {
    func testDenseCloudRecordKeepsSensorMetadataReadingsAndSubscriptionLimits() {
        let cloud = modelCloud()
        let record = modelRecord()
        let subscription = modelSubscription()
        let dense = AnyCloudSensorDense(sensor: cloud, record: record, subscription: subscription)
        XCTAssertEqual(recordValues(dense), recordValues(record))
        XCTAssertEqual(dense.id, cloud.id)
        XCTAssertEqual(dense.orderElement, cloud.id)
        XCTAssertEqual(dense.serviceUUID, cloud.serviceUUID)
        XCTAssertEqual(dense.name, cloud.name)
        XCTAssertEqual(dense.isClaimed, cloud.isClaimed)
        XCTAssertEqual(dense.isOwner, cloud.isOwner)
        XCTAssertEqual(dense.owner, cloud.owner)
        XCTAssertEqual(dense.picture, cloud.picture)
        XCTAssertEqual(dense.offsetTemperature, cloud.offsetTemperature)
        XCTAssertEqual(dense.offsetHumidity, cloud.offsetHumidity)
        XCTAssertEqual(dense.offsetPressure, cloud.offsetPressure)
        XCTAssertEqual(dense.isCloudSensor, cloud.isCloudSensor)
        XCTAssertEqual(dense.canShare, cloud.canShare)
        XCTAssertEqual(dense.sharedTo, cloud.sharedTo)
        XCTAssertEqual(dense.sharedToPending, cloud.sharedToPending)
        XCTAssertEqual(dense.lastUpdated, cloud.lastUpdated)
        XCTAssertEqual(dense.ownersPlan, "business")
        XCTAssertEqual(dense.maxHistoryDays, 365)
        let withoutSubscription = AnyCloudSensorDense(sensor: cloud, record: record, subscription: nil)
        XCTAssertNil(withoutSubscription.ownersPlan)
        XCTAssertNil(withoutSubscription.maxHistoryDays)
        XCTAssertEqual(dense, withoutSubscription)
        XCTAssertEqual(Set([dense, withoutSubscription]).count, 1)
        var other = cloud
        other.id = "other"
        XCTAssertNotEqual(dense, AnyCloudSensorDense(sensor: other, record: record, subscription: subscription))
    }

    func testRecordIdentityEditsAndCalibrationPreserveEveryUnrelatedReading() {
        let record = modelRecord()
        let original = recordValues(record)
        XCTAssertEqual(recordValues(record.any), original)
        for (key, value, edited) in [
            ("luid", "new-local", record.with(luid: "new-local".luid)),
            ("mac", "AA:BB:CC:11:22:33", record.with(macId: "AA:BB:CC:11:22:33".mac)),
            ("source", String(describing: RuuviTagSensorRecordSource.log), record.with(source: .log)),
        ] {
            var expected = original
            expected[key] = value
            XCTAssertEqual(recordValues(edited), expected)
        }
        let settings = SensorSettingsStruct(
            luid: record.luid, macId: record.macId, temperatureOffset: 2, humidityOffset: 0.03, pressureOffset: 4)
        var expected = original
        expected["temperatureOffset"] = "2.0"
        expected["humidityOffset"] = "0.03"
        expected["pressureOffset"] = "4.0"
        expected["temperature"] = "22.0"
        expected["humidity"] = "0.53"
        expected["pressure"] = "1017.0"
        XCTAssertEqual(recordValues(record.with(sensorSettings: settings)), expected)
        XCTAssertEqual(recordValues(record.with(sensorSettings: nil)), original)
        XCTAssertEqual(record.measurement.temperature, record.temperature)
        XCTAssertEqual(record.measurement.humidity, record.humidity)
        XCTAssertEqual(record.measurement.pressure, record.pressure)
        XCTAssertEqual(record.measurement.soundAvg, record.dbaAvg)
        XCTAssertEqual(record.measurement.soundPeak, record.dbaPeak)
        XCTAssertEqual(record.measurement.measurementSequenceNumber, record.measurementSequenceNumber)
    }

    func testMeasurementAvailabilityMatchesEachStoredFieldIncludingSoundAndCounters() {
        let record = modelRecord()
        let fields: [(MeasurementType, (inout RuuviTagSensorRecordStruct) -> Void)] = [
            (.temperature, { $0.temperature = nil }), (.humidity, { $0.humidity = nil }),
            (.pressure, { $0.pressure = nil }), (.co2, { $0.co2 = nil }), (.pm10, { $0.pm1 = nil }),
            (.pm25, { $0.pm25 = nil }), (.pm40, { $0.pm4 = nil }), (.pm100, { $0.pm10 = nil }),
            (.voc, { $0.voc = nil }), (.nox, { $0.nox = nil }), (.luminosity, { $0.luminance = nil }),
            (.soundInstant, { $0.dbaInstant = nil }), (.soundAverage, { $0.dbaAvg = nil }),
            (.soundPeak, { $0.dbaPeak = nil }), (.voltage, { $0.voltage = nil }), (.rssi, { $0.rssi = nil }),
            (.accelerationX, { $0.acceleration = nil }), (.accelerationY, { $0.acceleration = nil }),
            (.accelerationZ, { $0.acceleration = nil }), (.movementCounter, { $0.movementCounter = nil }),
            (.measurementSequenceNumber, { $0.measurementSequenceNumber = nil }), (.txPower, { $0.txPower = nil }),
        ]
        for (type, clear) in fields {
            XCTAssertTrue(record.hasMeasurement(for: type), "\(type)")
            var missing = record
            clear(&missing)
            XCTAssertFalse(missing.hasMeasurement(for: type), "\(type)")
        }
        XCTAssertTrue(record.hasMeasurement(for: .aqi))
        var missing = record
        missing.co2 = nil
        XCTAssertFalse(missing.hasMeasurement(for: .aqi))
        missing = record
        missing.pm25 = nil
        XCTAssertFalse(missing.hasMeasurement(for: .aqi))
    }

    func testHistoryMappingPreservesOptionalReadingsAndNeverInventsBatteryVoltage() throws {
        var log = try XCTUnwrap(Data(repeating: 0, count: 32).ruuviLogE1())
        log.date = Date(timeIntervalSince1970: 42)
        log.temperature = 20
        log.humidity = 50
        log.pressure = 1013
        log.pm1 = 1; log.pm25 = 2; log.pm4 = 3; log.pm10 = 4
        log.co2 = 800; log.voc = 100; log.nox = 5
        log.luminosity = 123; log.soundInstant = 30; log.soundAvg = 25; log.soundPeak = 40
        log.measurementSequenceNumber = 12345
        log.batteryVoltage = 3
        let record = log.ruuviSensorRecord(uuid: "device", mac: "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(record.luid?.value, "device")
        XCTAssertEqual(record.macId?.value, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(record.date, log.date)
        XCTAssertEqual(record.source, .log)
        XCTAssertEqual(record.temperature?.value, 20)
        XCTAssertEqual(record.humidity?.value, 0.5)
        XCTAssertEqual(record.pressure?.value, 1013)
        XCTAssertEqual(record.voltage?.value, 3)
        XCTAssertEqual(
            [
                record.pm1, record.pm25, record.pm4, record.pm10, record.co2, record.voc, record.nox,
                record.luminance, record.dbaInstant, record.dbaAvg, record.dbaPeak,
            ],
            [1, 2, 3, 4, 800, 100, 5, 123, 30, 25, 40])
        XCTAssertEqual(record.measurementSequenceNumber, 12345)
        XCTAssertNil(record.acceleration)
        XCTAssertNil(record.rssi)
        XCTAssertEqual(record.temperatureOffset, 0)
        log.batteryVoltage = nil
        log.temperature = nil; log.pressure = nil; log.humidity = nil
        let missing = log.ruuviSensorRecord(uuid: "device", mac: nil)
        XCTAssertNil(missing.macId)
        XCTAssertNil(missing.temperature)
        XCTAssertNil(missing.humidity)
        XCTAssertNil(missing.pressure)
        XCTAssertNil(missing.voltage)
        log.humidity = -1
        XCTAssertNil(log.ruuviSensorRecord(uuid: "device", mac: nil).humidity)
    }
}

func modelRecord() -> RuuviTagSensorRecordStruct {
    .init(
        luid: "local".luid, date: Date(timeIntervalSince1970: 100), source: .advertisement,
        macId: "AA:BB:CC:DD:EE:FF".mac, rssi: -42, version: 225,
        temperature: .init(value: 20, unit: .celsius),
        humidity: Humidity(relative: 0.5, temperature: .init(value: 20, unit: .celsius)),
        pressure: .init(value: 1013, unit: .hectopascals),
        acceleration: .init(
            x: .init(value: 0.1, unit: .metersPerSecondSquared),
            y: .init(value: -0.2, unit: .metersPerSecondSquared),
            z: .init(value: 1, unit: .metersPerSecondSquared)),
        voltage: .init(value: 3, unit: .volts), movementCounter: 2, measurementSequenceNumber: 5, txPower: 4,
        pm1: 1, pm25: 2, pm4: 3, pm10: 4, co2: 800, voc: 100, nox: 5, luminance: 123,
        dbaInstant: 30, dbaAvg: 25, dbaPeak: 40, temperatureOffset: 0, humidityOffset: 0, pressureOffset: 0)
}

func modelSubscription() -> CloudSensorSubscriptionStruct {
    .init(
        macId: "AA:BB:CC:DD:EE:FF", subscriptionName: "business", isActive: true, maxClaims: 10,
        maxHistoryDays: 365, maxResolutionMinutes: 1, maxShares: 100, maxSharesPerSensor: 10,
        delayedAlertAllowed: true, emailAlertAllowed: false, offlineAlertAllowed: true,
        pdfExportAllowed: false, pushAlertAllowed: true, telegramAlertAllowed: false, endAt: "2030-01-01")
}

func recordValues(_ record: RuuviTagSensorRecord) -> [String: String] {
    var values: [String: String] = [
        "luid": record.luid?.value ?? "-", "mac": record.macId?.value ?? "-",
        "date": String(record.date.timeIntervalSince1970), "source": String(describing: record.source),
        "version": String(record.version),
        "rssi": record.rssi.map(String.init) ?? "-", "movement": record.movementCounter.map(String.init) ?? "-",
        "sequence": record.measurementSequenceNumber.map(String.init) ?? "-",
        "power": record.txPower.map(String.init) ?? "-",
        "temperatureOffset": String(record.temperatureOffset), "humidityOffset": String(record.humidityOffset),
        "pressureOffset": String(record.pressureOffset),
    ]
    let readings: [String: Double?] = [
        "temperature": record.temperature?.value, "humidity": record.humidity?.value,
        "pressure": record.pressure?.value, "voltage": record.voltage?.value,
        "x": record.acceleration?.x.value, "y": record.acceleration?.y.value, "z": record.acceleration?.z.value,
        "pm1": record.pm1, "pm25": record.pm25, "pm4": record.pm4, "pm10": record.pm10,
        "co2": record.co2, "voc": record.voc, "nox": record.nox, "luminance": record.luminance,
        "instant": record.dbaInstant, "average": record.dbaAvg, "peak": record.dbaPeak,
    ]
    for (key, value) in readings { values[key] = value.map { String($0) } ?? "-" }
    return values
}
