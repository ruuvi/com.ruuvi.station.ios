#if canImport(Combine)
import Foundation
import GRDB
import Combine
import RealmSwift
import RuuviOntology
import RuuviContext

@available(iOS 13, *)
class RuuviTagLastRecordSubjectCombine {
    var isServing: Bool = false

    private var sqlite: SQLiteContext
    private var realm: RealmContext
    private var luid: String

    let subject = PassthroughSubject<AnyRuuviTagSensorRecord, Never>()

    private var ruuviTagDataRealmToken: NotificationToken?
    private var ruuviTagDataTransactionObserver: TransactionObserver?
    deinit {
        ruuviTagDataRealmToken?.invalidate()
    }

    init(luid: String, sqlite: SQLiteContext, realm: RealmContext) {
        self.sqlite = sqlite
        self.realm = realm
        self.luid = luid
    }

    func start() {
        self.isServing = true
        let request = RuuviTagDataSQLite.order(RuuviTagDataSQLite.dateColumn.desc)
                                        .filter(RuuviTagDataSQLite.ruuviTagIdColumn == luid)
        let observation = request.observationForFirst()

        self.ruuviTagDataTransactionObserver = try! observation.start(in: sqlite.database.dbPool) {
            [weak self] record in
            if let lastRecord = record?.any {
                self?.subject.send(lastRecord)
            }
        }
        let results = self.realm.main.objects(RuuviTagDataRealm.self)
            .filter("ruuviTag.uuid == %@", luid)
            .sorted(byKeyPath: "date")
        self.ruuviTagDataRealmToken = results.observe { [weak self] (change) in
            guard let sSelf = self else { return }
            switch change {
            case .update(let records, _, _, _):
                if let lastRecord = records.last?.any {
                    sSelf.subject.send(lastRecord)
                }
            default:
                break
            }
        }
    }
}
#endif
