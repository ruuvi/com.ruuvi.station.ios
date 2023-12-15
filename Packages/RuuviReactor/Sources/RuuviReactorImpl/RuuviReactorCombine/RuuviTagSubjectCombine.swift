import Combine
import Foundation
import GRDB
import RuuviContext
import RuuviOntology

final class RuuviTagSubjectCombine {
    var sqlite: SQLiteContext

    let insertSubject = PassthroughSubject<AnyRuuviTagSensor, Never>()
    let updateSubject = PassthroughSubject<AnyRuuviTagSensor, Never>()
    let deleteSubject = PassthroughSubject<AnyRuuviTagSensor, Never>()

    private var ruuviTagController: FetchedRecordsController<RuuviTagSQLite>

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    init(sqlite: SQLiteContext) {
        self.sqlite = sqlite

        let request = RuuviTagSQLite.order(RuuviTagSQLite.versionColumn)
        ruuviTagController = try! FetchedRecordsController(sqlite.database.dbPool, request: request)
        try! ruuviTagController.performFetch()

        ruuviTagController.trackChanges(onChange: { [weak self] _, record, event in
            guard let sSelf = self else { return }
            switch event {
            case .insertion:
                DispatchQueue.main.async {
                    sSelf.insertSubject.send(record.any)
                }
            case .update:
                DispatchQueue.main.async {
                    sSelf.updateSubject.send(record.any)
                }
            case .deletion:
                DispatchQueue.main.async {
                    sSelf.deleteSubject.send(record.any)
                }
            case .move:
                break
            }
        })
    }
}
