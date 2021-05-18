import Foundation
import GRDB
import Future

class RuuviTagReactorImpl: RuuviTagReactor {
    typealias SQLiteEntity = RuuviTagSQLite
    typealias RealmEntity = RuuviTagRealm

    var sqliteContext: SQLiteContext!
    var realmContext: RealmContext!
    var sqlitePersistence: RuuviTagPersistence!
    var realmPersistence: RuuviTagPersistence!
    var settings: Settings!

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
            var recordSubjectRxSwift: RuuviTagRecordSubjectRxSwift
            if let rxSwift = recordRxSwifts[ruuviTagId] {
                recordSubjectRxSwift = rxSwift
            } else {
                let rxSwift = RuuviTagRecordSubjectRxSwift(ruuviTagId: ruuviTagId,
                                                           sqlite: sqliteContext,
                                                           realm: realmContext)
                recordRxSwifts[ruuviTagId] = rxSwift
                recordSubjectRxSwift = rxSwift
            }
            let cancellable = recordSubjectRxSwift.subject.subscribe(onNext: { values in
                block(values)
            })
            if !recordSubjectRxSwift.isServing {
                recordSubjectRxSwift.start()
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
// swiftlint:disable:next function_body_length
    func observe(_ block: @escaping (ReactorChange<AnyRuuviTagSensor>) -> Void) -> RUObservationToken {
        let sqliteOperation = sqlitePersistence.readAll()
        let realmOperation = realmPersistence.readAll()
        Future.zip(realmOperation, sqliteOperation)
            .on(success: { [weak self] realmEntities, sqliteEntities in
            let combinedValues = sqliteEntities + realmEntities
            if let strongSelf = self {
                block(.initial(strongSelf.reorder(combinedValues)))
            } else {
                block(.initial(combinedValues))
            }
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
// swiftlint:disable:next function_body_length
    func observeLast(_ ruuviTag: RuuviTagSensor,
                     _ block: @escaping (ReactorChange<AnyRuuviTagSensorRecord?>) -> Void) -> RUObservationToken {
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
                let combine = RuuviTagLastRecordSubjectCombine(ruuviTagId: ruuviTag.id,
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
            return RUObservationToken {
                cancellable.cancel()
            }
        } else {
            var recordRxSwift: RuuviTagLastRecordSubjectRxSwift
            if let rxSwift = lastRecordRxSwifts[ruuviTag.id] {
                recordRxSwift = rxSwift
            } else {
                let rxSwift = RuuviTagLastRecordSubjectRxSwift(ruuviTagId: ruuviTag.id,
                                                               sqlite: sqliteContext,
                                                               realm: realmContext)
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
            return RUObservationToken {
                cancellable.dispose()
            }
        }
        #else
        var recordRxSwift: RuuviTagLastRecordSubjectRxSwift
        if let rxSwift = lastRecordRxSwifts[ruuviTag.id] {
            recordRxSwift = rxSwift
        } else {
            let rxSwift = RuuviTagLastRecordSubjectRxSwift(ruuviTagId: ruuviTag.id,
                                                           sqlite: sqliteContext,
                                                           realm: realmContext)
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
        return RUObservationToken {
            cancellable.dispose()
        }
        #endif
    }
// swiftlint:disable:next function_body_length
    func observe(_ ruuviTag: RuuviTagSensor,
                 _ block: @escaping (ReactorChange<SensorSettings>) -> Void) -> RUObservationToken {
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
                let combine = SensorSettingsCombine(ruuviTagId: ruuviTag.id,
                                                           sqlite: sqliteContext,
                                                           realm: realmContext)
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
            
            return RUObservationToken {
                insert.cancel()
                update.cancel()
                delete.cancel()
            }
        } else {
            var settingsRxSwift: SensorSettingsRxSwift
            if let rxSwift = sensorSettingsRxSwifts[ruuviTag.id] {
                settingsRxSwift = rxSwift
            } else {
                let rxSwift = SensorSettingsRxSwift(ruuviTagId: ruuviTag.id,
                                                               sqlite: sqliteContext,
                                                               realm: realmContext)
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
            return RUObservationToken {
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
            let rxSwift = SensorSettingsRxSwift(ruuviTagId: ruuviTag.id,
                                                           sqlite: sqliteContext,
                                                           realm: realmContext)
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
        return RUObservationToken {
            insert.dispose()
            update.dispose()
            delete.dispose()
        }
        #endif
    }
}
extension RuuviTagReactorImpl {
    private func reorder(_ sensors: [AnyRuuviTagSensor]) -> [AnyRuuviTagSensor] {
        if settings.tagsSorting.isEmpty {
            settings.tagsSorting = sensors.map({$0.id})
            return sensors
        } else {
            return sensors.reorder(by: settings.tagsSorting)
        }
    }
}
