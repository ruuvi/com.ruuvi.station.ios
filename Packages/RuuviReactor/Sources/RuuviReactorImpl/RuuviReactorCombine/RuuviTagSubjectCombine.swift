import Combine
import Foundation
import GRDB
import RuuviAnalytics
import RuuviContext
import RuuviOntology

final class RuuviTagSubjectCombine {
    var sqlite: SQLiteContext

    let insertSubject = PassthroughSubject<AnyRuuviTagSensor, Never>()
    let updateSubject = PassthroughSubject<AnyRuuviTagSensor, Never>()
    let deleteSubject = PassthroughSubject<AnyRuuviTagSensor, Never>()

    private let errorReporter: RuuviErrorReporter
    private var previousData: [RuuviTagSQLite] = []
    private var ruuviTagDataTransactionObserver: AnyDatabaseCancellable?

    deinit {
        ruuviTagDataTransactionObserver?.cancel()
    }

    init(
        sqlite: SQLiteContext,
        errorReporter: RuuviErrorReporter
    ) {
        self.sqlite = sqlite
        self.errorReporter = errorReporter

        let request = RuuviTagSQLite.order(RuuviTagSQLite.versionColumn)
        let observation = ValueObservation.tracking { db in try! request.fetchAll(db) }

        try! sqlite.database.dbPool.read { [weak self] db in
            guard let self else { return }
            self.previousData = try! request.fetchAll(db)

            ruuviTagDataTransactionObserver = observation.start(
                in: sqlite.database.dbPool
            ) { [weak self] error in
                self?.errorReporter.report(error: error)
            } onChange: { [weak self] newData in
                guard let self else { return }
                // Find inserts (present in newData but not in previousData)
                let inserts = newData.filter { newItem in
                    !self.previousData.contains { $0.id == newItem.id }
                }

                // Find deletes (present in previousData but not in newData)
                let deletes = self.previousData.filter { oldItem in
                    !newData.contains { $0.id == oldItem.id }
                }

                // Find updates (present in both, but maybe different in some other properties)
                let updates = newData.filter { newItem in
                    self.previousData.contains { $0.id == newItem.id && $0.any != newItem.any }
                }

                if !inserts.isEmpty {
                    DispatchQueue.main.async {
                        inserts.forEach { self.insertSubject.send($0.any) }
                    }
                }
                if !updates.isEmpty {
                    DispatchQueue.main.async {
                        updates.forEach { self.updateSubject.send($0.any) }
                    }
                }
                if !deletes.isEmpty {
                    DispatchQueue.main.async {
                        deletes.forEach { self.deleteSubject.send($0.any) }
                    }
                }

                // Update previousData for the next onChange call
                self.previousData = newData
            }
        }
    }
}
