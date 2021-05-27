import Foundation
import Future
import RuuviOntology

final class RuuviCloudPure: RuuviCloud {
    func load() -> Future<[AnyRuuviTagSensor], RuuviCloudError> {
        let promise = Promise<[AnyRuuviTagSensor], RuuviCloudError>()
        return promise.future
    }

    private lazy var queue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
}
