import Foundation
import Future
import CoreLocation

protocol WebTagService {

    func add(provider: WeatherProvider) -> Future<WeatherProvider, RUError>
    func add(provider: WeatherProvider, location: Location) -> Future<WeatherProvider, RUError>
    func remove(webTag: WebTagRealm) -> Future<Bool, RUError>
    func update(name: String, of webTag: WebTagRealm) -> Future<Bool, RUError>
    func update(location: Location, of webTag: WebTagRealm) -> Future<Bool, RUError>
    func clearLocation(of webTag: WebTagRealm) -> Future<Bool, RUError>

    // swiftlint:disable function_parameter_count
    @discardableResult
    func observeData<T: AnyObject>(_ observer: T,
                                   coordinate: CLLocationCoordinate2D,
                                   provider: WeatherProvider,
                                   interval: TimeInterval,
                                   fire: Bool,
                                   closure: @escaping (T, WPSData?, RUError?) -> Void) -> RUObservationToken
    // swiftlint:enable function_parameter_count

    @discardableResult
    func observeCurrentLocationData<T: AnyObject>(_ observer: T,
                                                  provider: WeatherProvider,
                                                  interval: TimeInterval,
                                                  fire: Bool,
                                                  closure: @escaping (T, WPSData?, Location?, RUError?) -> Void)
        -> RUObservationToken
}
