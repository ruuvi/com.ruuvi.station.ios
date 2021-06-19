import Foundation
import GRDB
import Future
import RuuviOntology
import RuuviContext
import RuuviPersistence
import RuuviReactor
#if canImport(RuuviOntologyRealm)
import RuuviOntologyRealm
#endif
#if canImport(RuuviOntologySQLite)
import RuuviOntologySQLite
#endif

class RuuviReactorImpl: RuuviReactor {
    typealias SQLiteEntity = RuuviTagSQLite
    typealias RealmEntity = RuuviTagRealm

    private let sqliteContext: SQLiteContext
    private let realmContext: RealmContext
    private let sqlitePersistence: RuuviPersistence
    private let realmPersistence: RuuviPersistence

    init(
        sqliteContext: SQLiteContext,
        realmContext: RealmContext,
        sqlitePersistence: RuuviPersistence,
        realmPersistence: RuuviPersistence
    ) {
        self.sqliteContext = sqliteContext
        self.realmContext = realmContext
        self.sqlitePersistence = sqlitePersistence
        self.realmPersistence = realmPersistence
    }

    private lazy var entityCombine = RuuviTagSubjectCombine(
        sqlite: sqliteContext,
        realm: realmContext
    )
    private lazy var recordCombines = [String: RuuviTagRecordSubjectCombine]()
    private lazy var lastRecordCombines = [String: RuuviTagLastRecordSubjectCombine]()
    private lazy var sensorSettingsCombines = [String: SensorSettingsCombine]()

    func observe(_ luid: LocalIdentifier,
                 _ block: @escaping ([AnyRuuviTagSensorRecord]) -> Void) -> RuuviReactorToken {
        var recordCombine: RuuviTagRecordSubjectCombine
        if let combine = recordCombines[luid.value] {
            recordCombine = combine
        } else {
            let combine = RuuviTagRecordSubjectCombine(
                luid: luid,
                macId: nil,
                sqlite: sqliteContext,
                realm: realmContext
            )
            recordCombines[luid.value] = combine
            recordCombine = combine
        }
        let cancellable = recordCombine.subject.sink { values in
            block(values)
        }
        if !recordCombine.isServing {
            recordCombine.start()
        }
        return RuuviReactorToken {
            cancellable.cancel()
        }
    }

    func observe(_ block: @escaping (RuuviReactorChange<AnyRuuviTagSensor>) -> Void) -> RuuviReactorToken {
        let sqliteOperation = sqlitePersistence.readAll()
        let realmOperation = realmPersistence.readAll()
        Future.zip(realmOperation, sqliteOperation)
            .on(success: { realmEntities, sqliteEntities in
            let combinedValues = sqliteEntities + realmEntities
            block(.initial(combinedValues))
        }, failure: { error in
            block(.error(.ruuviPersistence(error)))
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
        return RuuviReactorToken {
            insert.cancel()
            update.cancel()
            delete.cancel()
        }
    }
    func observeLast(_ ruuviTag: RuuviTagSensor,
                     _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void) -> RuuviReactorToken {
        let sqliteOperation = sqlitePersistence.readLast(ruuviTag)
        let realmOperation = realmPersistence.readLast(ruuviTag)
        Future.zip(realmOperation, sqliteOperation).on(success: { (realmRecord, sqliteRecord) in
            let result = [realmRecord, sqliteRecord].compactMap({$0?.any}).last
            block(.update(result))
        })
        var recordCombine: RuuviTagLastRecordSubjectCombine
        if let combine = lastRecordCombines[ruuviTag.id] {
            recordCombine = combine
        } else {
            let combine = RuuviTagLastRecordSubjectCombine(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                sqlite: sqliteContext,
                realm: realmContext
            )
            lastRecordCombines[ruuviTag.id] = combine
            recordCombine = combine
        }
        let cancellable = recordCombine.subject.sink { (record) in
            block(.update(record))
        }
        if !recordCombine.isServing {
            recordCombine.start()
        }
        return RuuviReactorToken {
            cancellable.cancel()
        }
    }

    func observe(_ ruuviTag: RuuviTagSensor,
                 _ block: @escaping (RuuviReactorChange<SensorSettings>) -> Void) -> RuuviReactorToken {
        sqlitePersistence.readSensorSettings(ruuviTag).on { sqliteRecord in
            if let sensorSettings = sqliteRecord {
                block(.update(sensorSettings))
            }
        }
        var sensorSettingsCombine: SensorSettingsCombine
        if let combine = sensorSettingsCombines[ruuviTag.id] {
            sensorSettingsCombine = combine
        } else {
            let combine = SensorSettingsCombine(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                sqlite: sqliteContext,
                realm: realmContext
            )
            sensorSettingsCombines[ruuviTag.id] = combine
            sensorSettingsCombine = combine
        }
        let insert = sensorSettingsCombine.insertSubject.sink { value in
            block(.insert(value))
        }
        let update = sensorSettingsCombine.updateSubject.sink { value in
            block(.update(value))
        }
        let delete = sensorSettingsCombine.deleteSubject.sink { value in
            block(.delete(value))
        }

        return RuuviReactorToken {
            insert.cancel()
            update.cancel()
            delete.cancel()
        }
    }
}
