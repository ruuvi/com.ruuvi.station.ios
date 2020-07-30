import Foundation
import GRDB
import Future

class VirtualTagReactorImpl: VirtualTagReactor {

    var realmContext: RealmContext!
    var realmPersistence: WebTagPersistence!

    private lazy var entityRxSwift = VirtualTagSubjectRxSwift(realm: realmContext)
    #if canImport(Combine)
    @available(iOS 13, *)
    private lazy var entityCombine = VirtualTagSubjectCombine(realm: realmContext)
    #endif

    func observe(_ block: @escaping (ReactorChange<AnyVirtualTagSensor>) -> Void) -> RUObservationToken {
        let realmOperation = realmPersistence.readAll()
        realmOperation.on(success: { realmEntities in
            block(.initial(realmEntities))
        }, failure: { error in
            block(.error(error))
        })

        #if canImport(Combine)
        if #available(iOS 13, *) {
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
        } else {
            let insert = entityRxSwift.insertSubject.subscribe(onNext: { value in
                block(.insert(value))
            })
            let update = entityRxSwift.updateSubject.subscribe(onNext: { value in
                block(.update(value))
            })
            let delete = entityRxSwift.deleteSubject.subscribe(onNext: { value in
                block(.delete(value))
            })
            return RUObservationToken {
                insert.dispose()
                update.dispose()
                delete.dispose()
            }
        }
        #else
        let insert = entityRxSwift.insertSubject.subscribe(onNext: { value in
            block(.insert(value))
        })
        let update = entityRxSwift.updateSubject.subscribe(onNext: { value in
            block(.update(value))
        })
        let delete = entityRxSwift.deleteSubject.subscribe(onNext: { value in
            block(.delete(value))
        })
        return RUObservationToken {
            insert.dispose()
            update.dispose()
            delete.dispose()
        }
        #endif
    }

}
