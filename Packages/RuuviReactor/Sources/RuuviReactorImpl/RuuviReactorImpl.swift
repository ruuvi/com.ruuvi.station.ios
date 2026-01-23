import Foundation
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

    init(
        sqliteContext: SQLiteContext,
        sqlitePersistence: RuuviPersistence,
        errorReporter: RuuviErrorReporter
    ) {
        self.sqliteContext = sqliteContext
        self.sqlitePersistence = sqlitePersistence
        self.errorReporter = errorReporter
    }

    private lazy var entityCombine = RuuviTagSubjectCombine(
        sqlite: sqliteContext,
        errorReporter: errorReporter
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
                sqlite: sqliteContext,
                errorReporter: errorReporter
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
        Task { [sqlitePersistence] in
            do {
                let sqliteEntities = try await sqlitePersistence.readAll()
                DispatchQueue.main.async {
                    block(.initial(sqliteEntities))
                }
            } catch let error as RuuviPersistenceError {
                DispatchQueue.main.async {
                    block(.error(.ruuviPersistence(error)))
                }
            }
        }

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
        Task { [sqlitePersistence] in
            let sqliteRecord = try? await sqlitePersistence.readLast(ruuviTag)
            let result = [sqliteRecord].compactMap { $0?.any }.last
            DispatchQueue.main.async {
                block(.update(result))
            }
        }
        var recordCombine: RuuviTagLastRecordSubjectCombine
        if let combine = lastRecordCombines[ruuviTag.id] {
            recordCombine = combine
        } else {
            let combine = RuuviTagLastRecordSubjectCombine(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                sqlite: sqliteContext,
                errorReporter: errorReporter
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
        Task { [sqlitePersistence] in
            let sqliteRecord = try? await sqlitePersistence.readLatest(ruuviTag)
            let result = [sqliteRecord].compactMap { $0?.any }.last
            DispatchQueue.main.async {
                block(.update(result))
            }
        }
        var recordCombine: RuuviTagLatestRecordSubjectCombine
        if let combine = latestRecordCombines[ruuviTag.id] {
            recordCombine = combine
        } else {
            let combine = RuuviTagLatestRecordSubjectCombine(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                sqlite: sqliteContext,
                errorReporter: errorReporter
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
        Task { [sqlitePersistence] in
            if let sensorSettings = try? await sqlitePersistence.readSensorSettings(ruuviTag) {
                DispatchQueue.main.async {
                    block(.initial([sensorSettings]))
                }
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
                errorReporter: errorReporter
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
