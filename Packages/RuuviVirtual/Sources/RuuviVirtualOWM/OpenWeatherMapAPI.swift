import Foundation
import Future

public protocol OpenWeatherMapAPI {
    func loadCurrent(
        longitude: Double,
        latitude: Double
    ) -> Future<OWMData, OWMError>
}

public struct OWMData {
    var kelvin: Double?
    var humidity: Double? // in %
    var pressure: Double? // in hPa
}
