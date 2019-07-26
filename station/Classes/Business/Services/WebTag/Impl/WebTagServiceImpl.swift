import Foundation
import Future

class WebTagServiceImpl: WebTagService {
    
    var webTagPersistence: WebTagPersistence!
    
    func add(provider: WeatherProvider) -> Future<WeatherProvider,RUError> {
        return webTagPersistence.persist(provider: provider)
    }
    
}
