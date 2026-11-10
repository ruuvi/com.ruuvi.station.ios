import Foundation
import Future
import RuuviPool

enum RuuviCloudAlertRetry {
    // A background notification response must remain alive until retry persistence
    // finishes. Never enqueue an old session's failed request into a new account.
    static func persist(
        error: RuuviCloudApiError,
        isCurrentSession: Bool,
        enqueue: () -> Future<Bool, RuuviPoolError>?
    ) -> Future<Void, RuuviCloudError> {
        let promise = Promise<Void, RuuviCloudError>()
        guard isCurrentSession else {
            promise.fail(error: .notAuthorized)
            return promise.future
        }
        guard let persistence = enqueue() else {
            promise.fail(error: .api(error))
            return promise.future
        }
        persistence.on(completion: {
            // Persistence schedules a retry; it does not mean the server accepted
            // the update. Preserve the failure until a later synchronization.
            promise.fail(error: .api(error))
        })
        return promise.future
    }
}
