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
    case apiLimitExceeded
    case invalidApiKey
    case notAHttpResponse
}

extension OWMError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToParseOpenWeatherMapResponse:
            return "OWMError.failedToParseOpenWeatherMapResponse".localized()
        case .apiLimitExceeded:
            return "OWMError.apiLimitExceeded".localized()
        case .notAHttpResponse:
            return "OWMError.notAHttpResponse".localized()
        case .invalidApiKey:
            return "OWMError.invalidApiKey".localized()
        }
    }
}
