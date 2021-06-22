import Foundation
import Future
import RuuviOntology
import RuuviContext
import RuuviVirtual

public final class VirtualReactorImpl: VirtualReactor {
    private let context: RealmContext
    private let persistence: VirtualPersistence
    private lazy var entityCombine = VirtualTagSubjectCombine(realm: context)
    private lazy var lastRecordCombines = [String: VirtualTagLastRecordSubjectCombine]()

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

    public func observeLast(
        _ virtualTag: VirtualTagSensor,
        _ block: @escaping (VirtualReactorChange<AnyVirtualTagSensorRecord?>) -> Void
    ) -> VirtualReactorToken {
        let realmOperation = persistence.readLast(virtualTag)
        realmOperation.on(success: { record in
            block(.update(record?.any))
        })
        var recordCombine: VirtualTagLastRecordSubjectCombine
        if let combine = lastRecordCombines[virtualTag.id] {
            recordCombine = combine
        } else {
            let combine = VirtualTagLastRecordSubjectCombine(
                id: virtualTag.id,
                realm: context
            )
            lastRecordCombines[virtualTag.id] = combine
            recordCombine = combine
        }
        let cancellable = recordCombine.subject.sink { (record) in
            block(.update(record))
        }
        if !recordCombine.isServing {
            recordCombine.start()
        }
        return VirtualReactorToken {
            cancellable.cancel()
        }
    }

}
