import Foundation
import GRDB
import Future
import RuuviOntology
import RuuviContext

class VirtualTagReactorImpl: VirtualTagReactor {
    var realmContext: RealmContext!
    var realmPersistence: WebTagPersistence!

    private lazy var entityCombine = VirtualTagSubjectCombine(realm: realmContext)

    func observe(_ block: @escaping (ReactorChange<AnyVirtualTagSensor>) -> Void) -> RUObservationToken {
        let realmOperation = realmPersistence.readAll()
        realmOperation.on(success: { realmEntities in
            block(.initial(realmEntities))
        }, failure: { error in
            block(.error(error))
        })
        let insert = entityCombine.insertSubject.sink { value in
            block(.insert(value))
        }
        let update = entityCombine.updateSubject.sink { value in
            block(.update(value))
        }
        let delete = entityCombine.deleteSubject.sink { value in
            block(.delete(value))
        }
        return RUObservationToken {
            insert.cancel()
            update.cancel()
            delete.cancel()
        }
    }

}
