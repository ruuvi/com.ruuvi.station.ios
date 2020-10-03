import Foundation

struct WPSData {
    var celsius: Double?
    var relativeHumidity: Double?
    var hPa: Double?
}

extension WPSData {
    var temperature: Temperature? {
        return Temperature(celsius, unit: .celsius)
    }
    var humidity: Humidity? {
        guard let relative = relativeHumidity else {
            return nil
        }
        return Humidity(relative: relative / 100.0, temperature: temperature)
    }
    var pressure: Pressure? {
        return Pressure(hPa, unit: .hectopascals)
    }
}
