import Foundation
import Future

final class RuuviNetworkPure: RuuviNetwork {
    func load(
        from provider: Any
    ) -> Future<Bool, RuuviNetworkError> {
        let promise = Promise<Bool, RuuviNetworkError>()
        return promise.future
    }

    private lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
}
