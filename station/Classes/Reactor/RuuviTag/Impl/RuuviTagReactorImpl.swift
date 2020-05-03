import Foundation
import GRDB
import RealmSwift
import Future

class RuuviTagReactorImpl: RuuviTagReactor {
    typealias SQLiteEntity = RuuviTagSQLite
    typealias RealmEntity = RuuviTagRealm

    var sqliteContext: SQLiteContext!
    var realmContext: RealmContext!
    var sqlitePersistence: RuuviTagPersistenceSQLite!
    var realmPersistence: RuuviTagPersistenceRealm!

    private lazy var entityRxSwift = RuuviTagSubjectRxSwift(sqlite: sqliteContext, realm: realmContext)
    #if canImport(Combine)
    @available(iOS 13, *)
    private lazy var entityCombine = RuuviTagSubjectCombine(sqlite: sqliteContext, realm: realmContext)
    #endif

    func observe(_ block: @escaping (ReactorChange<RuuviTagSensor>) -> Void) -> RUObservationToken {
        let sqliteOperation = sqlitePersistence.readAll()
        let realmOperation = realmPersistence.readAll()
        Future.zip(realmOperation, sqliteOperation).on(success: { realmEntities, sqliteEntities in
            block(.initial(sqliteEntities + realmEntities))
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
        let insert = rxSwift.insertSubject.subscribe(onNext: { value in
            block(.insert(value))
        })
        let update = rxSwift.updateSubject.subscribe(onNext: { value in
            block(.update(value))
        })
        let delete = rxSwift.deleteSubject.subscribe(onNext: { value in
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
