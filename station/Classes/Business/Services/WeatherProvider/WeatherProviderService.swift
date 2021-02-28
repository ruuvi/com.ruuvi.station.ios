import Foundation
import Future
import CoreLocation

protocol WeatherProviderService {

    func loadData(coordinate: CLLocationCoordinate2D, provider: WeatherProvider) -> Future<WPSData, RUError>
    func loadCurrentLocationData(from provider: WeatherProvider) -> Future<(Location, WPSData), RUError>

    @discardableResult
    func observeCurrentLocationData<T: AnyObject>(_ observer: T,
                                                  provider: WeatherProvider,
                                                  interval: TimeInterval,
                                                  fire: Bool,
                                                  closure: @escaping (T, WPSData?, Location?, RUError?) -> Void)
        -> RUObservationToken

    // swiftlint:disable function_parameter_count
    @discardableResult
    func observeData<T: AnyObject>(_ observer: T,
                                   coordinate: CLLocationCoordinate2D,
                                   provider: WeatherProvider,
                                   interval: TimeInterval,
                                   fire: Bool,
                                   closure: @escaping (T, WPSData?, RUError?) -> Void)
        -> RUObservationToken
    // swiftlint:enable function_parameter_count
}
