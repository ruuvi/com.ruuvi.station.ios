import Foundation

struct WPSData {
    var celsius: Double?
    var relativeHumidity: Double?
    var hPa: Double?
}

extension WPSData {
    var temperature: Temperature? {
        return Temperature(celsius)
    }
    var humidity: Humidity? {
        return Humidity(relative: relativeHumidity, temperature: temperature)
    }
    var pressure: Pressure? {
        return Pressure(hPa, unit: .hectopascals)
    }
}
