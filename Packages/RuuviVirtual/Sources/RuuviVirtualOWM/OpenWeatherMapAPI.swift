import Foundation
import Future
import RuuviVirtual

public protocol OpenWeatherMapAPI {
    func loadCurrent(
        longitude: Double,
        latitude: Double
    ) -> Future<OWMData, OWMError>
}

public struct OWMData {
    public var kelvin: Double?
    public var humidity: Double? // in %
    public var pressure: Double? // in hPa
}
