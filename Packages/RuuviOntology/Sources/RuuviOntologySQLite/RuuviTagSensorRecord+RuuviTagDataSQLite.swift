import Foundation

public extension RuuviTagSensorRecord {
    var sqlite: RuuviTagDataSQLite {
        RuuviTagDataSQLite(
            luid: luid,
            date: date,
            source: source,
            macId: macId,
            rssi: rssi,
            version: version,
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

    var latest: RuuviTagLatestDataSQLite {
        RuuviTagLatestDataSQLite(
            id: uuid,
            luid: luid,
            date: date,
            source: source,
            macId: macId,
            rssi: rssi,
            version: version,
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
