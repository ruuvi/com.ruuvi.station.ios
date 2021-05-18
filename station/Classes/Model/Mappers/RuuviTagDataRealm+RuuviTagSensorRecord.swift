import Foundation

extension RuuviTagDataRealm {

    var any: AnyRuuviTagSensorRecord? {
        guard let ruuviTagId = ruuviTag?.uuid else { return nil }
        let inner = RuuviTagSensorRecordStruct(ruuviTagId: ruuviTagId,
                                               date: date,
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
                                               pressureOffset: pressureOffset)
        
        return AnyRuuviTagSensorRecord(object: inner)
    }
}
