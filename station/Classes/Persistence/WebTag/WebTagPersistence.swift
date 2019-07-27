import Foundation
import Future

protocol WebTagPersistence {
    func persist(provider: WeatherProvider) -> Future<WeatherProvider,RUError>
    func remove(webTag: WebTagRealm) -> Future<Bool,RUError>
}
