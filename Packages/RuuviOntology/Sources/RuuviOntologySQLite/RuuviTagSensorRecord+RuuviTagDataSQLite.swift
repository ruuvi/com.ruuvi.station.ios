import Foundation
import RuuviOntology

extension RuuviTagSensorRecord {
    public var sqlite: RuuviTagDataSQLite {
        return RuuviTagDataSQLite(
            luid: luid,
            date: date,
            source: source,
            macId: macId,
            rssi: rssi,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            acceleration: acceleration,
            voltage: voltage,
            movementCounter: movementCounter,
            measurementSequenceNumber: measurementSequenceNumber,
            txPower: txPower,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset
        )
    }

    public var latest: RuuviTagLatestDataSQLite {
        return RuuviTagLatestDataSQLite(
            id: uuid,
            luid: luid,
            date: date,
            source: source,
            macId: macId,
            rssi: rssi,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            acceleration: acceleration,
            voltage: voltage,
            movementCounter: movementCounter,
            measurementSequenceNumber: measurementSequenceNumber,
            txPower: txPower,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset
        )
    }
}
