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

    private lazy var rxSwift = RuuviTagSubjectRxSwift(sqlite: sqliteContext, realm: realmContext)
    #if canImport(Combine)
    @available(iOS 13, *)
    private lazy var combine = RuuviTagSubjectCombine(sqlite: sqliteContext, realm: realmContext)
    #endif

    func observe(_ block: @escaping (ReactorChange<RuuviTagSensor>) -> Void) -> RUObservationToken {

        let sqliteOperation = sqlitePersistence.read()
        let realmOperation = realmPersistence.read()
        Future.zip(realmOperation, sqliteOperation).on(success: { realmEntities, sqliteEntities in
            block(.initial(sqliteEntities + realmEntities))
        }, failure: { error in
            block(.error(error))
        })

        #if canImport(Combine)
        if #available(iOS 13, *) {
            let cancellable = combine.insertSubject.sink { value in
                block(.insert(value))
            }
            return RUObservationToken {
                cancellable.cancel()
            }
        } else {
            let cancellable = rxSwift.insertSubject.subscribe(onNext: { value in
                block(.insert(value))
            })
            return RUObservationToken {
                cancellable.dispose()
            }
        }
        #else
        let cancellable = rxSwift.insertSubject.subscribe(onNext: { value in
            block(.insert(value))
        })
        return RUObservationToken {
            cancellable.dispose()
        }
        #endif
    }

}
