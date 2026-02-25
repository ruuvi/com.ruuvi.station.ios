import Foundation
import Humidity
import RuuviLocal
import RuuviOntology

extension WidgetSensorRecordSnapshot {
    func toRecord() -> RuuviTagSensorRecordStruct {
        let temperatureMeasurement = Temperature(temperature)
        let humidityMeasurement: Humidity?
        if let humidity, let temperatureMeasurement {
            humidityMeasurement = Humidity(relative: humidity, temperature: temperatureMeasurement)
        } else {
            humidityMeasurement = nil
        }
        let pressureMeasurement = Pressure(pressure)
        let acceleration: Acceleration?
        if let accelerationX, let accelerationY, let accelerationZ {
            acceleration = Acceleration(
                x: AccelerationMeasurement(value: accelerationX, unit: .metersPerSecondSquared),
                y: AccelerationMeasurement(value: accelerationY, unit: .metersPerSecondSquared),
                z: AccelerationMeasurement(value: accelerationZ, unit: .metersPerSecondSquared)
            )
        } else {
            acceleration = nil
        }
        let voltageMeasurement: Voltage? = {
            if let voltage {
                return Voltage(value: voltage, unit: .volts)
            }
            return nil
        }()
        return RuuviTagSensorRecordStruct(
            luid: luid?.luid,
            date: date,
            source: RuuviTagSensorRecordSource(rawValue: source) ?? .unknown,
            macId: macId?.mac,
            rssi: rssi,
            version: version,
            temperature: temperatureMeasurement,
            humidity: humidityMeasurement,
            pressure: pressureMeasurement,
            acceleration: acceleration,
            voltage: voltageMeasurement,
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
            temperatureOffset: temperatureOffset ?? 0.0,
            humidityOffset: humidityOffset ?? 0.0,
            pressureOffset: pressureOffset ?? 0.0
        )
    }
}
