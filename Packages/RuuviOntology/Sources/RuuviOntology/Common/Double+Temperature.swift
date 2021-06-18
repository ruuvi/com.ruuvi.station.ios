import Foundation

extension Double {
    public var fahrenheit: Double {
        return self * 9.0/5.0 + 32.0
    }

    public var kelvin: Double {
        return self + 273.15
    }

    public var celsiusFromFahrenheit: Double {
        return (self - 32.0) * 5.0/9.0
    }

    public var celsiusFromKelvin: Double {
        return self - 273.15
    }
}
