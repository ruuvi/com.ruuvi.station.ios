import Foundation
import Future

class VirtualTagTankCoordinator: VirtualTagTank {

    var realm: WebTagPersistenceRealm!

    func deleteAll(id: String, before: Date) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        // FIXME: implement
        return promise.future
    }
}
