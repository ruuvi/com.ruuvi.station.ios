import Foundation
import Future

public protocol RuuviCloud {
    @discardableResult
    func load(
        from provider: Any
    ) -> Future<Bool, RuuviCloudError>
}

public protocol RuuviCloudFactory {
    func create() -> RuuviCloud
}
