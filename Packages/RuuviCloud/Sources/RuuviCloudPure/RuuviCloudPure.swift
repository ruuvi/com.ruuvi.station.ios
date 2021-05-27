import Foundation
import Future

final class RuuviCloudPure: RuuviCloud {
    func load(
        from provider: Any
    ) -> Future<Bool, RuuviCloudError> {
        let promise = Promise<Bool, RuuviCloudError>()
        return promise.future
    }

    private lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
}
