import Foundation

public final class RuuviCloudFactoryPure: RuuviCloudFactory {
    public func create() -> RuuviCloud {
        return RuuviCloudPure()
    }
}
