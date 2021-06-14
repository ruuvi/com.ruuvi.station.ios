import Foundation
import RuuviUser

public final class RuuviCloudFactoryPure: RuuviCloudFactory {
    public init() {}

    public func create(baseUrl: URL, user: RuuviUser) -> RuuviCloud {
        let api = RuuviCloudApiURLSession(baseUrl: baseUrl)
        let cloud = RuuviCloudPure(api: api, user: user)
        return cloud
    }
}
