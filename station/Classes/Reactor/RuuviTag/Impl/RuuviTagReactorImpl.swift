import Foundation
import GRDB
import RealmSwift
import Future

class RuuviTagReactorImpl: RuuviTagReactor {
    typealias SQLiteEntity = RuuviTagSQLite
    typealias RealmEntity = RuuviTagRealm

    var sqliteContext: SQLiteContext!
    var realmContext: RealmContext!
    var sqlitePersistence: RuuviTagPersistence!
    var realmPersistence: RuuviTagPersistence!

    private lazy var entityRxSwift = RuuviTagSubjectRxSwift(sqlite: sqliteContext, realm: realmContext)
    private lazy var recordRxSwifts = [String: RuuviTagRecordSubjectRxSwift]()
    #if canImport(Combine)
    @available(iOS 13, *)
    private lazy var entityCombine = RuuviTagSubjectCombine(sqlite: sqliteContext, realm: realmContext)
    @available(iOS 13, *)
    private lazy var recordCombines = [String: RuuviTagRecordSubjectCombine]()
    #endif

    func observe(_ ruuviTagId: String,
                 _ block: @escaping ([AnyRuuviTagSensorRecord]) -> Void) -> RUObservationToken {
        #if canImport(Combine)
        if #available(iOS 13, *) {
            var recordCombine: RuuviTagRecordSubjectCombine
            if let combine = recordCombines[ruuviTagId] {
                recordCombine = combine
            } else {
                let combine = RuuviTagRecordSubjectCombine(ruuviTagId: ruuviTagId,
                                                           sqlite: sqliteContext,
                                                           realm: realmContext)
                recordCombines[ruuviTagId] = combine
                recordCombine = combine
            }
            let cancellable = recordCombine.subject.sink { values in
                block(values)
            }
            if !recordCombine.isServing {
                recordCombine.start()
            }
            return RUObservationToken {
                cancellable.cancel()
            }
        } else {
            var recordRxSwift: RuuviTagRecordSubjectRxSwift
            if let rxSwift = recordRxSwifts[ruuviTagId] {
                recordRxSwift = rxSwift
            } else {
                let rxSwift = RuuviTagRecordSubjectRxSwift(ruuviTagId: ruuviTagId,
                                                           sqlite: sqliteContext,
                                                           realm: realmContext)
                recordRxSwifts[ruuviTagId] = rxSwift
                recordRxSwift = rxSwift
            }
            let cancellable = recordRxSwift.subject.subscribe(onNext: { values in
                block(values)
            })
            if !recordRxSwift.isServing {
                recordRxSwift.start()
            }
            return RUObservationToken {
                cancellable.dispose()
            }
        }
        #else
        var recordRxSwift: RuuviTagRecordSubjectRxSwift
        if let rxSwift = recordRxSwifts[ruuviTagId] {
            recordRxSwift = rxSwift
        } else {
            let rxSwift = RuuviTagRecordSubjectRxSwift(ruuviTagId: ruuviTagId,
                                                       sqlite: sqliteContext,
                                                       realm: realmContext)
            recordRxSwifts[ruuviTagId] = rxSwift
            recordRxSwift = rxSwift
        }
        let cancellable = recordRxSwift.subject.subscribe(onNext: { values in
            block(values)
        })
        if !recordRxSwift.isServing {
            recordRxSwift.start()
        }
        return RUObservationToken {
            cancellable.dispose()
        }
        #endif
    }

    func observe(_ block: @escaping (ReactorChange<AnyRuuviTagSensor>) -> Void) -> RUObservationToken {
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
