import Foundation
import GRDB
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

    deinit {
        ruuviTagDataRealmToken?.invalidate()
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
        let observation = request.observationForFirst()

        self.ruuviTagDataTransactionObserver = try! observation.start(in: sqlite.database.dbPool) {
            [weak self] record in
            if let lastRecord = record?.any {
                self?.subject.onNext(lastRecord)
            }
        }
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
