import Foundation

public final class RuuviCloudFactoryPure: RuuviCloudFactory {
    public init() {}

    public func create(baseUrl: URL, apiKey: String?) -> RuuviCloud {
        let api = RuuviCloudApiURLSession(baseUrl: baseUrl)
        let cloud = RuuviCloudPure(api: api, apiKey: apiKey)
        return cloud
    }
}
