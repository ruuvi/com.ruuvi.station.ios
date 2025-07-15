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
            pm1: pm1,
            pm25: pm25,
            pm4: pm4,
            pm10: pm10,
            co2: co2,
            voc: voc,
            nox: nox,
            luminance: luminance,
            dbaInstant: dbaInstant,
            dbaAvg: dbaAvg,
            dbaPeak: dbaPeak,
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
            pm1: pm1,
            pm25: pm25,
            pm4: pm4,
            pm10: pm10,
            co2: co2,
            voc: voc,
            nox: nox,
            luminance: luminance,
            dbaInstant: dbaInstant,
            dbaAvg: dbaAvg,
            dbaPeak: dbaPeak,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset
        )
    }
}
