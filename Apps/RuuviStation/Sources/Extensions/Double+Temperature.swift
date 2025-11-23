import Foundation

extension Double {
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

extension Double {
    var inHg: Double {
        self * 0.02953
    }

    var mmHg: Double {
        self * 0.75006
    }

    var hPaFrominHg: Double {
        self * 33.86389
    }

    var hPaFrommmHg: Double {
        self * 1.33322
    }

    var hPaFromPa: Double {
        self / 100.0
    }
}
