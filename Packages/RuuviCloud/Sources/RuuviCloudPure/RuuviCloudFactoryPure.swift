import Foundation

public final class RuuviCloudFactoryPure: RuuviCloudFactory {
    public func create(baseUrl: URL) -> RuuviCloud {
        let cloud = RuuviCloudPure()
        return cloud
    }
}
