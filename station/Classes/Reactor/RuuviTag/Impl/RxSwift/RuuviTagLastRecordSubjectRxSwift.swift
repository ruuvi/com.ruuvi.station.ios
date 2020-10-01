import Foundation
import GRDB
import RxGRDB
import RxSwift
import RealmSwift

class RuuviTagLastRecordSubjectRxSwift {
    let subject: PublishSubject<AnyRuuviTagSensorRecord> = PublishSubject()
    var isServing: Bool = false

    private var sqlite: SQLiteContext
    private var realm: RealmContext
    private var ruuviTagId: String

    private var ruuviTagDataRealmToken: NotificationToken?
    private var ruuviTagDataTransactionObserver: TransactionObserver?
    private var observation: DatabaseCancellable?

    deinit {
        ruuviTagDataRealmToken?.invalidate()
        observation?.cancel()
        subject.onCompleted()
    }

    init(ruuviTagId: String, sqlite: SQLiteContext, realm: RealmContext) {
        self.sqlite = sqlite
        self.realm = realm
        self.ruuviTagId = ruuviTagId
    }

    func start() {
        self.isServing = true
        let request = RuuviTagDataSQLite.order(RuuviTagDataSQLite.dateColumn.desc)
                                        .filter(RuuviTagDataSQLite.ruuviTagIdColumn == ruuviTagId)
        let observation = ValueObservation.tracking({ db in
            try RuuviTagDataSQLite.fetchOne(db)
        })
        observation.publisher(in: <#T##DatabaseReader#>)


        self.ruuviTagDataTransactionObserver = try! observation.start(in: sqlite.database.dbPool) {
            [weak self] record in
            if let lastRecord = record?.any {
                self?.subject.onNext(lastRecord)
            }
        }
        self.ruuviTagDataTransactionObserver = try! observation.start(in: sqlite.database.dbPool,
                                                                      scheduling: .immediate,
                                                                      onError: { (error) in
                                                                        debugPrint(error)
                                                                      }, onChange: { [weak self] record in
                                                                        if let lastRecord = record?.any {
                                                                            self?.subject.onNext(lastRecord)
                                                                        }
                                                                      })
        let results = self.realm.main.objects(RuuviTagDataRealm.self)
            .filter("ruuviTag.uuid == %@", ruuviTagId)
            .sorted(byKeyPath: "date")
        self.ruuviTagDataRealmToken = results.observe { [weak self] (change) in
            guard let sSelf = self else { return }
            switch change {
            case .update(let records, _, _, _):
                if let lastRecord = records.last?.any {
                    sSelf.subject.onNext(lastRecord)
                }
            default:
                break
            }
        }
    }
}
