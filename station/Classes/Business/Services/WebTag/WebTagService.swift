import Foundation
import Future

protocol WebTagService {
    func add(provider: WeatherProvider) -> Future<WeatherProvider,RUError>
}
