import Foundation
import Future
import RuuviVirtual

public final class VirtualRepositoryCoordinator: VirtualRepository {
    private let peristence: VirtualPersistence

    public init(persistence: VirtualPersistence) {
        self.peristence = persistence
    }

    @discardableResult
    public func deleteAllRecords(
        _ id: String,
        before date: Date
    ) -> Future<Bool, VirtualRepositoryError> {
        let promise = Promise<Bool, VirtualRepositoryError>()
        peristence.deleteAllRecords(id, before: date)
            .on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .virtualPersistence(error))
            })
        return promise.future
    }
}
