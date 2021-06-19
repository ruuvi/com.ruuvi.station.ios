import Foundation
import RuuviOntology

extension RuuviTagSensorRecord {
    public var measurement: RuuviMeasurement {
        return RuuviMeasurement(
            luid: luid,
            macId: macId,
            measurementSequenceNumber: measurementSequenceNumber,
            date: date,
            rssi: rssi,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            acceleration: acceleration,
            voltage: voltage,
            movementCounter: movementCounter,
            txPower: txPower
        )
    }
}
