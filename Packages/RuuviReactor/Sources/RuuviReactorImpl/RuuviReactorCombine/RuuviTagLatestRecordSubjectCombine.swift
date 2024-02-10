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
                if let lastRecord = record?.any {
                    self?.subject.send(lastRecord)
                }
            }
        )
    }
}
