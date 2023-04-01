import Foundation
import RuuviPool
import RuuviUser
import RuuviCloud
#if canImport(RuuviCloudApi)
import RuuviCloudApi
#endif

public final class RuuviCloudFactoryPure: RuuviCloudFactory {
    public init() {}

    public func create(baseUrl: URL,
                       user: RuuviUser,
                       pool: RuuviPool) -> RuuviCloud {
        let api = RuuviCloudApiURLSession(baseUrl: baseUrl)
        let cloud = RuuviCloudPure(api: api, user: user, pool: pool)
        return cloud
    }
}
