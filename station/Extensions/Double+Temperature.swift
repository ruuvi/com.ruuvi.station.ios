import Foundation

extension Double {
    var fahrenheit: Double {
        return self * 9.0/5.0 + 32.0
    }

    var kelvin: Double {
        return self + 273.15
    }

    var celsiusFromFahrenheit: Double {
        return (self - 32.0) * 5.0/9.0
    }

    var celsiusFromKelvin: Double {
        return self - 273.15
    }
}

extension Double {
    var inHg: Double {
        return self * 0.02953
    }
    
    var mmHg: Double {
        return self * 0.75006
    }
    
    var hPaFrominHg: Double {
        return self * 33.86389
    }
    
    var hPaFrommmHg: Double {
        return self * 1.33322
    }
}
