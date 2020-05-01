#if canImport(Combine)
import Foundation
import GRDB
import Combine

@available(iOS 13, *)
class RuuviTagSubjectCombine {
    var sqlite: SQLiteContext
    var realm: RealmContext

    let insertSubject = PassthroughSubject<RuuviTagSQLite, Never>()
    let updateSubject = PassthroughSubject<RuuviTagSQLite, Never>()
    let deleteSubject = PassthroughSubject<RuuviTagSQLite, Never>()

    private var ruuviTagController: FetchedRecordsController<RuuviTagSQLite>

    init(sqlite: SQLiteContext, realm: RealmContext) {
        self.sqlite = sqlite
        self.realm = realm

        let request = RuuviTagSQLite.order(RuuviTagSQLite.versionColumn)
        self.ruuviTagController = try! FetchedRecordsController(sqlite.database.dbPool, request: request)
        try! self.ruuviTagController.performFetch()

        self.ruuviTagController.trackChanges(onChange: { [weak self] _, record, event in
            guard let sSelf = self else { return }
            switch event {
            case .insertion:
                sSelf.insertSubject.send(record)
            case .update:
                sSelf.updateSubject.send(record)
            case .deletion:
                sSelf.updateSubject.send(record)
            case .move:
                break
            }
        })
    }
}
#endif
