import Foundation
import Future

class WebTagServiceImpl: WebTagService {
    
    var webTagPersistence: WebTagPersistence!
    
    func add(provider: WeatherProvider, location: Location) -> Future<WeatherProvider,RUError> {
        return webTagPersistence.persist(provider: provider, location: location)
    }
    
    func add(provider: WeatherProvider) -> Future<WeatherProvider,RUError> {
        return webTagPersistence.persist(provider: provider)
    }
    
    func remove(webTag: WebTagRealm) -> Future<Bool,RUError> {
        return webTagPersistence.remove(webTag: webTag)
    }
    
    func update(name: String, of webTag: WebTagRealm) -> Future<Bool,RUError> {
        return webTagPersistence.update(name: name, of: webTag)
    }
    
    func update(location: Location, of webTag: WebTagRealm) -> Future<Bool,RUError> {
        return webTagPersistence.update(location: location, of: webTag)
    }
    
    func clearLocation(of webTag: WebTagRealm) -> Future<Bool,RUError> {
        return webTagPersistence.clearLocation(of: webTag)
    }

}
