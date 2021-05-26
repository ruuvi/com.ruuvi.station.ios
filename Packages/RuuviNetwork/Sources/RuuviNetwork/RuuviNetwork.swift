import Foundation
import Future

public protocol RuuviNetwork {
    @discardableResult
    func load(
        from provider: Any
    ) -> Future<Bool, RuuviNetworkError>
}

public protocol RuuviNetworkFactory {
    func create() -> RuuviNetwork
}
