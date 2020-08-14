import Foundation
import Humidity

protocol MeasurementsService {
    func double(for measurement: Measurement<Dimension>) -> Double
    func string(for measurement: Measurement<Dimension>) -> String
    func double(for humidity: Humidity, with offset: Double) -> Double
    func string(for humidity: Humidity, with offset: Double) -> String
}

protocol MeasurementsServiceDelegate: class {
    func measurementServiceDidUpdateUnit()
}
