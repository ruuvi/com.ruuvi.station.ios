import Foundation

public extension Double {
    var fahrenheit: Double {
        self * 9.0 / 5.0 + 32.0
    }

    var kelvin: Double {
        self + 273.15
    }

    var celsiusFromFahrenheit: Double {
        (self - 32.0) * 5.0 / 9.0
    }

    var celsiusFromKelvin: Double {
        self - 273.15
    }
}
