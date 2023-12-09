import Foundation

final class RuuviCloudApiFactoryURLSession: RuuviCloudApiFactory {
    func create(baseUrl: URL) -> RuuviCloudApi {
        RuuviCloudApiURLSession(baseUrl: baseUrl)
    }
}
