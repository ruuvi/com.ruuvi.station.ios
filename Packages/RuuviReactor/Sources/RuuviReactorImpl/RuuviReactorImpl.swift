import Foundation
import Future
import GRDB
import RuuviContext
import RuuviOntology
import RuuviPersistence

class RuuviReactorImpl: RuuviReactor {
    typealias SQLiteEntity = RuuviTagSQLite

    private let sqliteContext: SQLiteContext
    private let sqlitePersistence: RuuviPersistence

    init(
        sqliteContext: SQLiteContext,
        sqlitePersistence: RuuviPersistence
    ) {
        self.sqliteContext = sqliteContext
        self.sqlitePersistence = sqlitePersistence
    }

    private lazy var entityCombine = RuuviTagSubjectCombine(
        sqlite: sqliteContext
    )
    private lazy var recordCombines = [String: RuuviTagRecordSubjectCombine]()
    private lazy var lastRecordCombines = [String: RuuviTagLastRecordSubjectCombine]()
    private lazy var latestRecordCombines = [String: RuuviTagLatestRecordSubjectCombine]()
    private lazy var sensorSettingsCombines = [String: SensorSettingsCombine]()

    func observe(
        _ luid: LocalIdentifier,
        _ block: @escaping ([AnyRuuviTagSensorRecord]) -> Void
    ) -> RuuviReactorToken {
        var recordCombine: RuuviTagRecordSubjectCombine
        if let combine = recordCombines[luid.value] {
            recordCombine = combine
        } else {
            let combine = RuuviTagRecordSubjectCombine(
                luid: luid,
                macId: nil,
                sqlite: sqliteContext
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
        sqliteOperation
            .on(success: { sqliteEntities in
                let combinedValues = sqliteEntities
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

    func observeLast(
        _ ruuviTag: RuuviTagSensor,
        _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void
    ) -> RuuviReactorToken {
        let sqliteOperation = sqlitePersistence.readLast(ruuviTag)
        sqliteOperation
            .on(success: { sqliteRecord in
                let result = [sqliteRecord].compactMap { $0?.any }.last
                block(.update(result))
            })
        var recordCombine: RuuviTagLastRecordSubjectCombine
        if let combine = lastRecordCombines[ruuviTag.id] {
            recordCombine = combine
        } else {
            let combine = RuuviTagLastRecordSubjectCombine(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                sqlite: sqliteContext
            )
            lastRecordCombines[ruuviTag.id] = combine
            recordCombine = combine
        }
        let cancellable = recordCombine.subject.sink { record in
            block(.update(record))
        }
        if !recordCombine.isServing {
            recordCombine.start()
        }
        return RuuviReactorToken {
            cancellable.cancel()
        }
    }

    func observeLatest(
        _ ruuviTag: RuuviTagSensor,
        _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void
    ) -> RuuviReactorToken {
        let sqliteOperation = sqlitePersistence.readLatest(ruuviTag)
        sqliteOperation.on(success: { sqliteRecord in
            let result = [sqliteRecord].compactMap { $0?.any }.last
            block(.update(result))
        })
        var recordCombine: RuuviTagLatestRecordSubjectCombine
        if let combine = latestRecordCombines[ruuviTag.id] {
            recordCombine = combine
        } else {
            let combine = RuuviTagLatestRecordSubjectCombine(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                sqlite: sqliteContext
            )
            latestRecordCombines[ruuviTag.id] = combine
            recordCombine = combine
        }
        let cancellable = recordCombine.subject.sink { record in
            block(.update(record))
        }
        if !recordCombine.isServing {
            recordCombine.start()
        }
        return RuuviReactorToken {
            cancellable.cancel()
        }
    }

    func observe(
        _ ruuviTag: RuuviTagSensor,
        _ block: @escaping (RuuviReactorChange<SensorSettings>) -> Void
    ) -> RuuviReactorToken {
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
                sqlite: sqliteContext
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
