import Foundation
import GRDB
import Future
import RuuviOntology
import RuuviContext
import RuuviPersistence

// swiftlint:disable type_body_length
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

    private lazy var entityRxSwift = RuuviTagSubjectRxSwift(sqlite: sqliteContext, realm: realmContext)
    private lazy var recordRxSwifts = [String: RuuviTagRecordSubjectRxSwift]()
    private lazy var lastRecordRxSwifts = [String: RuuviTagLastRecordSubjectRxSwift]()
    private lazy var sensorSettingsRxSwifts = [String: SensorSettingsRxSwift]()
    #if canImport(Combine)
    @available(iOS 13, *)
    private lazy var entityCombine = RuuviTagSubjectCombine(sqlite: sqliteContext, realm: realmContext)
    @available(iOS 13, *)
    private lazy var recordCombines = [String: RuuviTagRecordSubjectCombine]()
    @available(iOS 13, *)
    private lazy var lastRecordCombines = [String: RuuviTagLastRecordSubjectCombine]()
    @available(iOS 13, *)
    private lazy var sensorSettingsCombines = [String: SensorSettingsCombine]()
    #endif

    // swiftlint:disable:next function_body_length
    func observe(_ luid: LocalIdentifier,
                 _ block: @escaping ([AnyRuuviTagSensorRecord]) -> Void) -> RuuviReactorToken {
        #if canImport(Combine)
        if #available(iOS 13, *) {
            var recordCombine: RuuviTagRecordSubjectCombine
            if let combine = recordCombines[luid.value] {
                recordCombine = combine
            } else {
                let combine = RuuviTagRecordSubjectCombine(
                    luid: luid.value,
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
        } else {
            var recordSubjectRxSwift: RuuviTagRecordSubjectRxSwift
            if let rxSwift = recordRxSwifts[luid.value] {
                recordSubjectRxSwift = rxSwift
            } else {
                let rxSwift = RuuviTagRecordSubjectRxSwift(
                    luid: luid,
                    sqlite: sqliteContext,
                    realm: realmContext
                )
                recordRxSwifts[luid.value] = rxSwift
                recordSubjectRxSwift = rxSwift
            }
            let cancellable = recordSubjectRxSwift.subject.subscribe(onNext: { values in
                block(values)
            })
            if !recordSubjectRxSwift.isServing {
                recordSubjectRxSwift.start()
            }
            return RuuviReactorToken {
                cancellable.dispose()
            }
        }
        #else
        var recordRxSwift: RuuviTagRecordSubjectRxSwift
        if let rxSwift = recordRxSwifts[luid.value] {
            recordRxSwift = rxSwift
        } else {
            let rxSwift = RuuviTagRecordSubjectRxSwift(
                luid: luid,
                sqlite: sqliteContext,
                realm: realmContext
            )
            recordRxSwifts[ruuviTagId] = rxSwift
            recordRxSwift = rxSwift
        }
        let cancellable = recordRxSwift.subject.subscribe(onNext: { values in
            block(values)
        })
        if !recordRxSwift.isServing {
            recordRxSwift.start()
        }
        return RuuviReactorToken {
            cancellable.dispose()
        }
        #endif
    }

    // swiftlint:disable:next function_body_length
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
            return RuuviReactorToken {
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
            return RuuviReactorToken {
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
        return RuuviReactorToken {
            insert.dispose()
            update.dispose()
            delete.dispose()
        }
        #endif
    }
// swiftlint:disable:next function_body_length
    func observeLast(_ ruuviTag: RuuviTagSensor,
                     _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void) -> RuuviReactorToken {
        let sqliteOperation = sqlitePersistence.readLast(ruuviTag)
        let realmOperation = realmPersistence.readLast(ruuviTag)
        Future.zip(realmOperation, sqliteOperation).on(success: { (realmRecord, sqliteRecord) in
            let result = [realmRecord, sqliteRecord].compactMap({$0?.any}).last
            block(.update(result))
        })
        #if canImport(Combine)
        if #available(iOS 13, *) {
            var recordCombine: RuuviTagLastRecordSubjectCombine
            if let combine = lastRecordCombines[ruuviTag.id] {
                recordCombine = combine
            } else {
                let combine = RuuviTagLastRecordSubjectCombine(luid: ruuviTag.id,
                                                           sqlite: sqliteContext,
                                                           realm: realmContext)
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
        } else {
            var recordRxSwift: RuuviTagLastRecordSubjectRxSwift
            if let rxSwift = lastRecordRxSwifts[ruuviTag.id] {
                recordRxSwift = rxSwift
            } else {
                let rxSwift = RuuviTagLastRecordSubjectRxSwift(
                    luid: ruuviTag.luid ?? ruuviTag.id.luid,
                    sqlite: sqliteContext,
                    realm: realmContext
                )
                lastRecordRxSwifts[ruuviTag.id] = rxSwift
                recordRxSwift = rxSwift
            }
            let cancellable = recordRxSwift.subject.subscribe { (record) in
                if let lastRecord = record.element {
                    block(.update(lastRecord))
                }
            }
            if !recordRxSwift.isServing {
                recordRxSwift.start()
            }
            return RuuviReactorToken {
                cancellable.dispose()
            }
        }
        #else
        var recordRxSwift: RuuviTagLastRecordSubjectRxSwift
        if let rxSwift = lastRecordRxSwifts[ruuviTag.id] {
            recordRxSwift = rxSwift
        } else {
            let rxSwift = RuuviTagLastRecordSubjectRxSwift(
                luid: ruuviTag.luid ?? ruuviTag.id.luid,
                sqlite: sqliteContext,
                realm: realmContext
            )
            lastRecordRxSwifts[ruuviTag.id] = rxSwift
            recordRxSwift = rxSwift
        }
        let cancellable = recordRxSwift.subject.subscribe { (record) in
            if let lastRecord = record.element {
                block(.update(lastRecord))
            }
        }
        if !recordRxSwift.isServing {
            recordRxSwift.start()
        }
        return RuuviReactorToken {
            cancellable.dispose()
        }
        #endif
    }

    // swiftlint:disable:next function_body_length
    func observe(_ ruuviTag: RuuviTagSensor,
                 _ block: @escaping (RuuviReactorChange<SensorSettings>) -> Void) -> RuuviReactorToken {
        sqlitePersistence.readSensorSettings(ruuviTag).on { sqliteRecord in
            if let sensorSettings = sqliteRecord {
                block(.update(sensorSettings))
            }
        }
        #if canImport(Combine)
        if #available(iOS 13, *) {
            var sensorSettingsCombine: SensorSettingsCombine
            if let combine = sensorSettingsCombines[ruuviTag.id] {
                sensorSettingsCombine = combine
            } else {
                let combine = SensorSettingsCombine(
                    luid: ruuviTag.luid ?? ruuviTag.id.luid,
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
        } else {
            var settingsRxSwift: SensorSettingsRxSwift
            if let rxSwift = sensorSettingsRxSwifts[ruuviTag.id] {
                settingsRxSwift = rxSwift
            } else {
                let rxSwift = SensorSettingsRxSwift(
                    luid: ruuviTag.luid ?? ruuviTag.id.luid,
                    sqlite: sqliteContext,
                    realm: realmContext
                )
                sensorSettingsRxSwifts[ruuviTag.id] = rxSwift
                settingsRxSwift = rxSwift
            }
            let insert = settingsRxSwift.insertSubject.subscribe(onNext: { value in
                block(.insert(value))
            })
            let update = settingsRxSwift.updateSubject.subscribe(onNext: { value in
                block(.update(value))
            })
            let delete = settingsRxSwift.deleteSubject.subscribe(onNext: { value in
                block(.delete(value))
            })
            return RuuviReactorToken {
                insert.dispose()
                update.dispose()
                delete.dispose()
            }
        }
        #else
        var sensorSettingsRxSwift: SensorSettingsRxSwift
        if let rxSwift = sensorSettingsRxSwifts[ruuviTag.id] {
            sensorSettingsRxSwift = rxSwift
        } else {
            let rxSwift = SensorSettingsRxSwift(
                luid: ruuviTag.luid ?? ruuviTag.id.luid,
                sqlite: sqliteContext,
                realm: realmContext
            )
            sensorSettingsRxSwifts[ruuviTag.id] = rxSwift
            sensorSettingsRxSwift = rxSwift
        }
        let insert = sensorSettingsRxSwift.insertSubject.subscribe(onNext: { value in
            block(.insert(value))
        })
        let update = sensorSettingsRxSwift.updateSubject.subscribe(onNext: { value in
            block(.update(value))
        })
        let delete = sensorSettingsRxSwift.deleteSubject.subscribe(onNext: { value in
            block(.delete(value))
        })
        return RuuviReactorToken {
            insert.dispose()
            update.dispose()
            delete.dispose()
        }
        #endif
    }
}
