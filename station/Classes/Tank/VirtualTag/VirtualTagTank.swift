import Foundation
import Future

protocol VirtualTagTank {

    @discardableResult
    func deleteAll(id: String, before: Date) -> Future<Bool, RUError>
}
