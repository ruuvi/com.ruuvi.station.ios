import Foundation

struct WPSData {
    var celsius: Double?
    var humidity: Double?
    var pressure: Double?

    var fahrenheit: Double? {
        return celsius?.fahrenheit
    }

    var kelvin: Double? {
        return celsius?.kelvin
    }
}
