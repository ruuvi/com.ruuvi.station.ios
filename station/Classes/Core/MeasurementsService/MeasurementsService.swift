import Foundation
import Humidity

protocol MeasurementsServiceDelegate: class {
    func measurementServiceDidUpdateUnit()
}

protocol MeasurementsService {
    var units: MeasurementsServiceSettigsUnit! { get }
    func add(_ listener: MeasurementsServiceDelegate)

    func double(for temperature: Temperature) -> Double
    func string(for temperature: Temperature?) -> String
    func double(for humidity: Humidity,
                withOffset offset: Double,
                temperature: Temperature,
                isDecimal: Bool) -> Double?
    func string(for humidity: Humidity?,
                withOffset offset: Double?,
                temperature: Temperature?) -> String
    func double(for pressure: Pressure) -> Double
    func string(for pressure: Pressure?) -> String
    func double(for voltage: Voltage) -> Double
    func string(for voltage: Voltage?) -> String
}
extension MeasurementsService {
    func double(for temperature: Temperature?) -> Double? {
        guard let temperature = temperature else {
            return nil
        }
        return double(for: temperature)
    }

    func double(for humidity: Humidity?,
                withOffset offset: Double?,
                temperature: Temperature?,
                isDecimal: Bool) -> Double? {
        guard let temperature = temperature,
            let humidity = humidity else {
            return nil
        }
        return double(for: humidity,
                      withOffset: offset ?? 0.0,
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
