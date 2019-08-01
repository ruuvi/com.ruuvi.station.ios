import Foundation
import Future

protocol WebTagService {
    
    func add(provider: WeatherProvider) -> Future<WeatherProvider,RUError>
    func add(provider: WeatherProvider, location: Location) -> Future<WeatherProvider,RUError>
    func remove(webTag: WebTagRealm) -> Future<Bool,RUError>
    func update(name: String, of webTag: WebTagRealm) -> Future<Bool,RUError>
    func update(location: Location, of webTag: WebTagRealm) -> Future<Bool,RUError>
    func clearLocation(of webTag: WebTagRealm) -> Future<Bool,RUError>
    
}
