import Foundation

public final class RuuviNetworkFactoryPure: RuuviNetworkFactory {
    public func create() -> RuuviNetwork {
        return RuuviNetworkPure()
    }
}
