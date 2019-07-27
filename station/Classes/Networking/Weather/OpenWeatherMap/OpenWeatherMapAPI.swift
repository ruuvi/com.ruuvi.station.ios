import Foundation
import Future

protocol OpenWeatherMapAPI {
    func loadCurrent(longitude: Double, latitude: Double) -> Future<OWMData,RUError>
}

struct OWMData {
    var kelvin: Double? 
    var humidity: Double? // in %
    var pressure: Double? // in hPa
}

enum OWMError: Error {
    case failedToParseOpenWeatherMapResponse
}

extension OWMError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToParseOpenWeatherMapResponse:
            return "OWMError.failedToParseOpenWeatherMapResponse".localized()
        }
    }
}
