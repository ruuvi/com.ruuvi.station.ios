import Foundation

final class RuuviCloudApiFactoryURLSession: RuuviCloudApiFactory {
    func create(baseUrl: URL) -> RuuviCloudApi {
        return RuuviCloudApiURLSession(baseUrl: baseUrl)
    }
}
