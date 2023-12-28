import Combine
import Foundation
import GRDB
import RuuviContext
import RuuviOntology

final class RuuviTagRecordSubjectCombine {
    var isServing: Bool = false

    private var sqlite: SQLiteContext
    private var luid: LocalIdentifier?
    private var macId: MACIdentifier?

    let subject = PassthroughSubject<[AnyRuuviTagSensorRecord], Never>()

    private var ruuviTagDataTransactionObserver: AnyDatabaseCancellable?

    init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        sqlite: SQLiteContext
    ) {
        self.sqlite = sqlite
        self.luid = luid
        self.macId = macId
    }

    deinit {
        ruuviTagDataTransactionObserver?.cancel()
    }

    func start() {
        isServing = true
        let request = RuuviTagDataSQLite.order(RuuviTagDataSQLite.dateColumn)
            .filter(
                (luid?.value != nil && RuuviTagDataSQLite.luidColumn == luid?.value)
                    || (macId?.value != nil && RuuviTagDataSQLite.macColumn == macId?.value)
            )

        let observation = ValueObservation.tracking { db in
            try request.fetchAll(db)
        }.removeDuplicates()

        ruuviTagDataTransactionObserver = observation.start(
            in: sqlite.database.dbPool,
            onError: { error in
                print(error.localizedDescription)
            },
            onChange: { [weak self] records in
                self?.subject.send(records.map(\.any))
            }
        )
    }
}
