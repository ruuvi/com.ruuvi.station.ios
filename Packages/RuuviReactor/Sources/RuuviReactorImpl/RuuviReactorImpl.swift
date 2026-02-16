import Foundation
import Future
import GRDB
import RuuviAnalytics
import RuuviContext
import RuuviOntology
import RuuviPersistence

class RuuviReactorImpl: RuuviReactor {
    typealias SQLiteEntity = RuuviTagSQLite

    private let sqliteContext: SQLiteContext
    private let sqlitePersistence: RuuviPersistence
    private let errorReporter: RuuviErrorReporter
    private let stateLock = NSLock()
    private let entityCombine: RuuviTagSubjectCombine

    private var recordCombines = [String: RuuviTagRecordSubjectCombine]()
    private var lastRecordCombines = [String: RuuviTagLastRecordSubjectCombine]()
    private var latestRecordCombines = [String: RuuviTagLatestRecordSubjectCombine]()
    private var sensorSettingsCombines = [String: SensorSettingsCombine]()

    init(
        sqliteContext: SQLiteContext,
        sqlitePersistence: RuuviPersistence,
        errorReporter: RuuviErrorReporter
    ) {
        self.sqliteContext = sqliteContext
        self.sqlitePersistence = sqlitePersistence
        self.errorReporter = errorReporter
        self.entityCombine = RuuviTagSubjectCombine(
            sqlite: sqliteContext,
            errorReporter: errorReporter
        )
    }

    private func synchronized<T>(_ block: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return block()
    }

    func observe(
        _ luid: LocalIdentifier,
        _ block: @escaping ([AnyRuuviTagSensorRecord]) -> Void
    ) -> RuuviReactorToken {
        let recordCombine: RuuviTagRecordSubjectCombine = synchronized {
            if let combine = recordCombines[luid.value] {
                return combine
            }
            let combine = RuuviTagRecordSubjectCombine(
                luid: luid,
                macId: nil,
                sqlite: sqliteContext,
                errorReporter: errorReporter
            )
            recordCombines[luid.value] = combine
            return combine
        }

        let cancellable = recordCombine.subject.sink { values in
            block(values)
        }

        let shouldStart = synchronized {
            if recordCombine.isServing {
                return false
            }
            recordCombine.isServing = true
            return true
        }
        if shouldStart {
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
        let recordCombine: RuuviTagLastRecordSubjectCombine = synchronized {
            if let combine = lastRecordCombines[ruuviTag.id] {
                return combine
            }
            let combine = RuuviTagLastRecordSubjectCombine(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                sqlite: sqliteContext,
                errorReporter: errorReporter
            )
            lastRecordCombines[ruuviTag.id] = combine
            return combine
        }

        let cancellable = recordCombine.subject.sink { record in
            block(.update(record))
        }

        let shouldStart = synchronized {
            if recordCombine.isServing {
                return false
            }
            recordCombine.isServing = true
            return true
        }
        if shouldStart {
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
        let recordCombine: RuuviTagLatestRecordSubjectCombine = synchronized {
            if let combine = latestRecordCombines[ruuviTag.id] {
                return combine
            }
            let combine = RuuviTagLatestRecordSubjectCombine(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                sqlite: sqliteContext,
                errorReporter: errorReporter
            )
            latestRecordCombines[ruuviTag.id] = combine
            return combine
        }

        let cancellable = recordCombine.subject.sink { record in
            block(.update(record))
        }

        let shouldStart = synchronized {
            if recordCombine.isServing {
                return false
            }
            recordCombine.isServing = true
            return true
        }
        if shouldStart {
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
                block(.initial([sensorSettings]))
            }
        }
        let sensorSettingsCombine: SensorSettingsCombine = synchronized {
            if let combine = sensorSettingsCombines[ruuviTag.id] {
                return combine
            }
            let combine = SensorSettingsCombine(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                sqlite: sqliteContext,
                errorReporter: errorReporter
            )
            sensorSettingsCombines[ruuviTag.id] = combine
            return combine
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
