import Foundation
import Future

protocol WebTagPersistence {
    func persist(provider: WeatherProvider) -> Future<WeatherProvider,RUError>
}
