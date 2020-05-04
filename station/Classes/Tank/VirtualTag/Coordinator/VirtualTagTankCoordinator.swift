import Foundation
import Future

class VirtualTagTankCoordinator: VirtualTagTank {

    var realm: WebTagPersistenceRealm!

    func deleteAllRecords(_ id: String, before date: Date) -> Future<Bool, RUError> {
        return realm.deleteAllRecords(id, before: date)
    }
}
