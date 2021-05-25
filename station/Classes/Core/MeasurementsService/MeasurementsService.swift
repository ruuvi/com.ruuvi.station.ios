import Foundation
import Humidity

protocol MeasurementsServiceDelegate: AnyObject {
    func measurementServiceDidUpdateUnit()
}

protocol MeasurementsService {
    var units: MeasurementsServiceSettigsUnit! { get set }
    func add(_ listener: MeasurementsServiceDelegate)
    /// update units cache without notify listeners
    func updateUnits()

    func double(for temperature: Temperature) -> Double
    func string(for temperature: Temperature?) -> String
    func stringWithoutSign(for temperature: Temperature?) -> String

    func double(for humidity: Humidity,
                temperature: Temperature,
                isDecimal: Bool) -> Double?

    func string(for humidity: Humidity?,
                temperature: Temperature?) -> String
    func double(for pressure: Pressure) -> Double
    func string(for pressure: Pressure?) -> String
    func double(for voltage: Voltage) -> Double
    func string(for voltage: Voltage?) -> String

    func temperatureOffsetCorrection(for temperature: Double) -> Double
    func temperatureOffsetCorrectionString(for temperature: Double) -> String

    func humidityOffsetCorrection(for temperature: Double) -> Double
    func humidityOffsetCorrectionString(for temperature: Double) -> String

    func pressureOffsetCorrection(for temperature: Double) -> Double
    func pressureOffsetCorrectionString(for temperature: Double) -> String
}
extension MeasurementsService {
    func double(for temperature: Temperature?) -> Double? {
        guard let temperature = temperature else {
            return nil
        }
        return double(for: temperature)
    }

    func double(for humidity: Humidity?,
                temperature: Temperature?,
                isDecimal: Bool) -> Double? {
        guard let temperature = temperature,
            let humidity = humidity else {
            return nil
        }
        return double(for: humidity,
                      temperature: temperature,
                      isDecimal: isDecimal)
    }

    func double(for pressure: Pressure?) -> Double? {
        guard let pressure = pressure else {
            return nil
        }
        return double(for: pressure)
    }

    func double(for voltage: Voltage?) -> Double? {
        guard let voltage = voltage else {
            return nil
        }
        return double(for: voltage)
    }
}
