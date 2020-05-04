import Foundation
import Future

protocol VirtualTagTank {

    @discardableResult
    func deleteAllRecords(_ id: String, before date: Date) -> Future<Bool, RUError>
}
