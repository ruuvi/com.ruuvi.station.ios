import Foundation
import Future
import CoreLocation

protocol WebTagPersistence {
    func persist(provider: WeatherProvider) -> Future<WeatherProvider, RUError>
    func persist(provider: WeatherProvider, location: Location) -> Future<WeatherProvider, RUError>
    func remove(webTag: WebTagRealm) -> Future<Bool, RUError>
    func update(name: String, of webTag: WebTagRealm) -> Future<Bool, RUError>
    func update(location: Location, of webTag: WebTagRealm) -> Future<Bool, RUError>
    func clearLocation(of webTag: WebTagRealm) -> Future<Bool, RUError>
    @discardableResult
    func persist(currentLocation: Location, data: WPSData) -> Future<WPSData, RUError>
    @discardableResult
    func persist(location: Location, data: WPSData) -> Future<WPSData, RUError>
}
