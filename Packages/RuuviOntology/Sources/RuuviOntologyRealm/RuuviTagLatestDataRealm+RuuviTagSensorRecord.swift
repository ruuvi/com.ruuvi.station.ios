import Foundation
import RealmSwift

public extension RuuviTagLatestDataRealm {
    var any: AnyRuuviTagSensorRecord? {
        let inner = RuuviTagSensorRecordStruct(
            luid: ruuviTag?.uuid.luid,
            date: date,
            source: source,
            macId: ruuviTag?.mac?.mac,
            rssi: rssi.value,
            temperature: unitTemperature,
            humidity: unitHumidity,
            pressure: unitPressure,
            acceleration: acceleration,
            voltage: unitVoltage,
            movementCounter: movementCounter.value,
            measurementSequenceNumber: measurementSequenceNumber.value,
            txPower: txPower.value,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset
        )
        return AnyRuuviTagSensorRecord(object: inner)
    }
}
