import Foundation

public extension RuuviTagSensorRecord {
    var measurement: RuuviMeasurement {
        RuuviMeasurement(
            luid: luid,
            macId: macId,
            measurementSequenceNumber: measurementSequenceNumber,
            date: date,
            rssi: rssi,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            co2: co2,
            pm25: pm25,
            pm10: pm10,
            voc: voc,
            nox: nox,
            luminosity: luminance,
            sound: dbaAvg,
            acceleration: acceleration,
            voltage: voltage,
            movementCounter: movementCounter,
            txPower: txPower,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset
        )
    }
}
