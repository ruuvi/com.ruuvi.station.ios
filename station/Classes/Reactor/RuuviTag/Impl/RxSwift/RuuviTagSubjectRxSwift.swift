import Foundation
import GRDB
import RxSwift

class RuuviTagSubjectRxSwift {
    var sqlite: SQLiteContext
    var realm: RealmContext
    
    let insertSubject: PublishSubject<RuuviTagSQLite> = PublishSubject()
    let updateSubject: PublishSubject<RuuviTagSQLite> = PublishSubject()
    let deleteSubject: PublishSubject<RuuviTagSQLite> = PublishSubject()
    
    private var ruuviTagController: FetchedRecordsController<RuuviTagSQLite>
    
    init(sqlite: SQLiteContext, realm: RealmContext) {
        self.sqlite = sqlite
        self.realm = realm
        
        let request = RuuviTagSQLite.order(RuuviTagSQLite.versionColumn)
        self.ruuviTagController = try! FetchedRecordsController(sqlite.database.dbPool, request: request)
        
        try! self.ruuviTagController.performFetch()
        self.ruuviTagController.trackChanges(onChange: { [weak self] controller, record, event in
            guard let sSelf = self else { return }
            switch event {
            case .insertion:
                sSelf.insertSubject.onNext(record)
            case .update:
                sSelf.updateSubject.onNext(record)
            case .deletion:
                sSelf.updateSubject.onNext(record)
            case .move:
                break
            }
        })
    }
}
