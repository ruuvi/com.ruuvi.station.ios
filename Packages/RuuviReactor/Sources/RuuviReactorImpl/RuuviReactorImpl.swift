import Foundation
import Future
import GRDB
import RuuviAnalytics
import RuuviContext
import RuuviOntology
import RuuviPersistence
import Combine

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

    private lazy var batchLatestRecordObserver = RuuviTagBatchedLatestRecordObserver(
        sqlite: sqliteContext,
        errorReporter: errorReporter
    )

    // Cache for individual tag subscriptions
    private var latestRecordSubscriptions: [String: Set<AnyCancellable>] = [:]
    private var currentlyObservedTags: [RuuviTagSensor] = []
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

        // Add this tag to our batch observation if not already included
        if !currentlyObservedTags.contains(where: { $0.id == ruuviTag.id }) {
            currentlyObservedTags.append(ruuviTag)
            restartBatchObserver()
        }

        // Subscribe to updates for this specific tag
        let cancellable = batchLatestRecordObserver.individualUpdateSubject
            .filter {
                $0.ruuviTag.luid?.value == ruuviTag.luid?.value ||
                $0.ruuviTag.macId?.value == ruuviTag.macId?.value
            }
            .sink { update in
                switch update.changeType {
                case .initial:
                    block(.update(update.record))
                case .updated:
                    block(.update(update.record))
                case .deleted:
                    block(.update(nil))
                }
            }

        // Store the subscription
        if latestRecordSubscriptions[ruuviTag.id] == nil {
            latestRecordSubscriptions[ruuviTag.id] = Set<AnyCancellable>()
        }
        latestRecordSubscriptions[ruuviTag.id]?.insert(cancellable)

        // Load initial data
        sqlitePersistence.readLatest(ruuviTag).on(success: { sqliteRecord in
            let result = sqliteRecord?.any
            block(.update(result))
        })

        return RuuviReactorToken { [weak self] in
            self?.removeObservation(for: ruuviTag)
        }
    }

    // MARK: - Batch Observation (New API)

    /// Observe all latest records in a single efficient query
    func observeAllLatestRecords(
        for ruuviTags: [RuuviTagSensor],
        _ block: @escaping (
            [AnyRuuviTagSensor: AnyRuuviTagSensorRecord?]
        ) -> Void
    ) -> RuuviReactorToken {

        currentlyObservedTags = ruuviTags
        batchLatestRecordObserver.start(for: ruuviTags)

        let cancellable = batchLatestRecordObserver.batchUpdateSubject.sink { updates in
            let recordDict = Dictionary(uniqueKeysWithValues: updates.map {
                ($0.ruuviTag, $0.record)
            })
            block(recordDict)
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

// MARK: - Private Methods
extension RuuviReactorImpl {
    private func removeObservation(for ruuviTag: RuuviTagSensor) {
        latestRecordSubscriptions[ruuviTag.id]?.removeAll()
        latestRecordSubscriptions.removeValue(forKey: ruuviTag.id)

        // Remove from observed tags and restart if needed
        currentlyObservedTags.removeAll { $0.id == ruuviTag.id }
        if !currentlyObservedTags.isEmpty {
            restartBatchObserver()
        } else {
            batchLatestRecordObserver.stop()
        }
    }

    private func restartBatchObserver() {
        batchLatestRecordObserver.stop()
        if !currentlyObservedTags.isEmpty {
            batchLatestRecordObserver.start(for: currentlyObservedTags)
        }
    }
}
