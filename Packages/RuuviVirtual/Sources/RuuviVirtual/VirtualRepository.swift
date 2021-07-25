import Foundation
import Future

public protocol VirtualRepository {
    @discardableResult
    func deleteAllRecords(
        _ id: String,
        before date: Date
    ) -> Future<Bool, VirtualRepositoryError>
}
