import Foundation
import RuuviOntology

public struct VirtualData {
    var celsius: Double?
    var relativeHumidity: Double?
    var hPa: Double?

    public init(celsius: Double?, relativeHumidity: Double?, hPa: Double?) {
        self.celsius = celsius
        self.relativeHumidity = relativeHumidity
        self.hPa = hPa
    }
}

extension VirtualData {
    public var temperature: Temperature? {
        return Temperature(celsius, unit: .celsius)
    }

    public var humidity: Humidity? {
        guard let relative = relativeHumidity else {
            return nil
        }
        return Humidity(relative: relative / 100.0, temperature: temperature)
    }

    public var pressure: Pressure? {
        return Pressure(hPa, unit: .hectopascals)
    }
}
