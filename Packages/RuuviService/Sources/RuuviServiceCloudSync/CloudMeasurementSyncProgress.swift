import Foundation
import Future
import RuuviLocal

/// Tracks measurement work independently of other requests, and waits for every write to settle.
enum CloudMeasurementSyncProgress {
    static func track<Value>(
        publish: @escaping (RuuviCloudSyncEvent) -> Void = { $0.publish() },
        _ work: () -> Future<Value, RuuviServiceError>
    ) -> Future<Value, RuuviServiceError> {
        let id = UUID()
        publish(.started(id))
        let future = work()
        future.observe(on: Scheduler.immediate).on(completion: { publish(.finished(id)) })
        return future
    }

    static func allSettled<Value>(
        _ futures: [Future<Value, RuuviServiceError>]
    ) -> Future<[Value], RuuviServiceError> {
        let settled = futures.map { future -> Future<Result<Value, RuuviServiceError>, Never> in
            let promise = Promise<Result<Value, RuuviServiceError>, Never>()
            future.observe(on: Scheduler.immediate).on(
                success: { promise.succeed(value: .success($0)) },
                failure: { promise.succeed(value: .failure($0)) }
            )
            return promise.future
        }
        return Future.zip(settled).flatMap { results -> Future<[Value], RuuviServiceError> in
            var values: [Value] = []
            for result in results {
                switch result {
                case .success(let value): values.append(value)
                case .failure(let error): return Future(error: error)
                }
            }
            return Future(value: values)
        }
    }
}
