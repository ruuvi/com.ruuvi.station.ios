import Combine
import Foundation
import GRDB
import RuuviAnalytics
import RuuviContext
import RuuviOntology

final class RuuviTagLatestRecordSubjectCombine {
    var isServing: Bool = false

    private var sqlite: SQLiteContext
    private var luid: LocalIdentifier?
    private var macId: MACIdentifier?

    let subject = PassthroughSubject<AnyRuuviTagSensorRecord, Never>()

    private let errorReporter: RuuviErrorReporter
    private var ruuviTagDataTransactionObserver: AnyDatabaseCancellable?
    private var previousRecord: RuuviTagLatestDataSQLite?

    deinit {
        ruuviTagDataTransactionObserver?.cancel()
    }

    init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        sqlite: SQLiteContext,
        errorReporter: RuuviErrorReporter
    ) {
        self.sqlite = sqlite
        self.luid = luid
        self.macId = macId
        self.errorReporter = errorReporter
    }

    func start() {
        isServing = true
        let request = RuuviTagLatestDataSQLite
            .order(RuuviTagLatestDataSQLite.dateColumn.desc)
            .filter(
                (luid?.value != nil && RuuviTagLatestDataSQLite.luidColumn == luid?.value)
                    || (macId?.value != nil && RuuviTagLatestDataSQLite.macColumn == macId?.value)
            )

        let observation = ValueObservation.tracking { db in
            try request.fetchOne(db)
        }

        ruuviTagDataTransactionObserver = observation.start(
            in: sqlite.database.dbPool,
            onError: { [weak self] error in
                self?.errorReporter.report(error: error)
            },
            onChange: { [weak self] record in
                let previousDate = self?.previousRecord?.date ?? Date.distantPast
                if let lastRecord = record, lastRecord.date > previousDate {
                    self?.subject.send(lastRecord.any)
                    self?.previousRecord = lastRecord
                }
            }
        )
    }
}

final class RuuviTagBatchedLatestRecordObserver {

    // MARK: - Types

    struct LatestRecordUpdate {
        let ruuviTag: AnyRuuviTagSensor
        let record: AnyRuuviTagSensorRecord?
        let changeType: ChangeType
    }

    enum ChangeType {
        case initial
        case updated
        case deleted
    }

    // MARK: - Properties

    private let sqlite: SQLiteContext
    private let errorReporter: RuuviErrorReporter
    private var observation: AnyDatabaseCancellable?
    private var previousRecords: [String: RuuviTagLatestDataSQLite] = [:]
    private var isServing = false

    // Publishers for different notification patterns
    let batchUpdateSubject = PassthroughSubject<[LatestRecordUpdate], Never>()
    let individualUpdateSubject = PassthroughSubject<LatestRecordUpdate, Never>()

    // MARK: - Initialization

    init(sqlite: SQLiteContext, errorReporter: RuuviErrorReporter) {
        self.sqlite = sqlite
        self.errorReporter = errorReporter
    }

    deinit {
        stop()
    }

    // MARK: - Control Methods

    func start(for ruuviTags: [RuuviTagSensor]) {
        guard !isServing else { return }
        isServing = true

        let tagIds = ruuviTags.compactMap { tag in
            tag.luid?.value ?? tag.macId?.value
        }

        guard !tagIds.isEmpty else { return }

        // Single query to get all latest records
        let request = RuuviTagLatestDataSQLite
            .filter(tagIds.contains(RuuviTagLatestDataSQLite.luidColumn) ||
                   tagIds.contains(RuuviTagLatestDataSQLite.macColumn))
            .order(RuuviTagLatestDataSQLite.dateColumn.desc)

        let valueObservation = ValueObservation
            .tracking { db in
                try request.fetchAll(db)
            }
            .removeDuplicates() // Crucial for performance

        observation = valueObservation.start(
            in: sqlite.database.dbPool,
            onError: { [weak self] error in
                self?.errorReporter.report(error: error)
            },
            onChange: { [weak self] records in
                self?.processRecordChanges(records, ruuviTags: ruuviTags)
            }
        )
    }

    func stop() {
        observation?.cancel()
        observation = nil
        isServing = false
        previousRecords.removeAll()
    }

    // MARK: - Private Methods

    private func processRecordChanges(
        _ records: [RuuviTagLatestDataSQLite], ruuviTags: [RuuviTagSensor]
    ) {
        var updates: [LatestRecordUpdate] = []
        let currentRecordDict = Dictionary(grouping: records) { record in
            record.luid?.value ?? record.macId?.value ?? ""
        }.compactMapValues { $0.first }

        // Process each RuuviTag
        for tag in ruuviTags {
            let tagId = tag.luid?.value ?? tag.macId?.value ?? ""
            let currentRecord = currentRecordDict[tagId]
            let previousRecord = previousRecords[tagId]

            let update: LatestRecordUpdate

            if let current = currentRecord {
                if let previous = previousRecord {
                    // Check if actually changed
                    if current.date != previous.date ||
                       current.measurementSequenceNumber != previous.measurementSequenceNumber {
                        update = LatestRecordUpdate(
                            ruuviTag: tag.any,
                            record: current.any,
                            changeType: .updated
                        )
                    } else {
                        continue // No real change
                    }
                } else {
                    // New record
                    update = LatestRecordUpdate(
                        ruuviTag: tag.any,
                        record: current.any,
                        changeType: .initial
                    )
                }
            } else {
                // Record deleted or not found
                if previousRecord != nil {
                    update = LatestRecordUpdate(
                        ruuviTag: tag.any,
                        record: nil,
                        changeType: .deleted
                    )
                } else {
                    continue // No change
                }
            }

            updates.append(update)
        }

        // Update cache
        previousRecords = currentRecordDict

        // Emit updates
        if !updates.isEmpty {
            batchUpdateSubject.send(updates)
            updates.forEach { individualUpdateSubject.send($0) }
        }
    }
}
