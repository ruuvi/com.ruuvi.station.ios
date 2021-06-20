import Foundation
import GRDB
import Future
import RuuviOntology
import RuuviContext

public final class VirtualReactorImpl: VirtualReactor {
    private let context: RealmContext
    private let persistence: VirtualPersistence
    private lazy var entityCombine = VirtualTagSubjectCombine(realm: context)

    public init(context: RealmContext, persistence: VirtualPersistence) {
        self.context = context
        self.persistence = persistence
    }

    public func observe(
        _ block: @escaping (VirtualReactorChange<AnyVirtualTagSensor>) -> Void
    ) -> VirtualReactorToken {
        let realmOperation = persistence.readAll()
        realmOperation.on(success: { realmEntities in
            block(.initial(realmEntities))
        }, failure: { error in
            block(.error(.virtualPersistence(error)))
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
        return VirtualReactorToken {
            insert.cancel()
            update.cancel()
            delete.cancel()
        }
    }

}
