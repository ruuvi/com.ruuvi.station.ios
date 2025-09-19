// Temporary bridging utilities during migration from Future/Promise to Swift Concurrency.
// Will be removed once all call sites are async/await.
//
// NOTE: Target platform iOS 16+ so we can rely on full async/await runtime.

import Foundation
#if canImport(Combine)
import Combine
#endif
#if canImport(Future)
import Future
#endif

// MARK: - Future -> async

#if canImport(Future)
public extension Future {
    @inlinable
    func asyncValue() async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            self.on(success: { value in
                continuation.resume(returning: value)
            }, failure: { error in
                if let error = error as? Error { // Failure is already Error
                    continuation.resume(throwing: error)
                } else {
                    // Fallback: wrap non-Error failure (shouldn't happen with kean/Future)
                    continuation.resume(throwing: NSError(domain: "FutureBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown failure type"]))
                }
            })
        }
    }
}
#endif

// MARK: - Async -> Future (avoid creating new usages; only for transitional reverse bridging)

#if canImport(Future)
@available(*, deprecated, message: "Use async/await directly; this will be removed when migration completes.")
public func futureify<T>(_ work: @escaping () async throws -> T) -> Future<T, Error> {
    Future { promise in
        Task {
            do { let value = try await work(); promise(.success(value)) }
            catch { promise(.failure(error)) }
        }
    }
}
#endif

// MARK: - Combine helpers

#if canImport(Combine)
public extension Publisher {
    /// Await the first value (or throw completion failure). Cancels upstream after first value.
    func firstAsync() async throws -> Output where Failure: Error {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                var cancellable: AnyCancellable?
                cancellable = self.first().sink { completion in
                    switch completion {
                    case let .failure(error):
                        continuation.resume(throwing: error)
                        cancellable?.cancel()
                    case .finished:
                        // If finished without value, treat as error
                        continuation.resume(throwing: NSError(domain: "FutureBridge", code: -2, userInfo: [NSLocalizedDescriptionKey: "Publisher finished without value"]))
                    }
                } receiveValue: { value in
                    continuation.resume(returning: value)
                    cancellable?.cancel()
                }
            }
        }, onCancel: { /* Nothing special; sink will auto-cancel on deinit */ })
    }
}
#endif

// MARK: - Deprecation markers for legacy patterns

#if canImport(Future)
@available(*, deprecated, message: "Use Task { await ... } instead of .on(success:) chaining")
public typealias _LegacyFuture<T, E: Error> = Future<T, E>
#endif
