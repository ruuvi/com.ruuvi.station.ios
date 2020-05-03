#if canImport(Combine)
import Foundation
import GRDB
import Combine
import RealmSwift

@available(iOS 13, *)
class RuuviTagRecordSubjectCombine {
    var clients: Int = 0

    private var sqlite: SQLiteContext
    private var realm: RealmContext
    private var ruuviTagId: String

    let subject = PassthroughSubject<[RuuviTagSensorRecord], Never>()

    private var ruuviTagDataRealmToken: NotificationToken?
    private var ruuviTagDataRealmCache = [AnyRuuviTagSensorRecord]()
    private var ruuviTagDataTransactionObserver: TransactionObserver?
    deinit {
        ruuviTagDataRealmToken?.invalidate()
    }

    init(ruuviTagId: String, sqlite: SQLiteContext, realm: RealmContext) {
        self.sqlite = sqlite
        self.realm = realm
        self.ruuviTagId = ruuviTagId
    }

    func start() {
        let request = RuuviTagDataSQLite.order(RuuviTagDataSQLite.dateColumn)
                                        .filter(RuuviTagDataSQLite.ruuviTagIdColumn == ruuviTagId)
        let observation = ValueObservation.tracking { db -> [RuuviTagDataSQLite] in
            try! request.fetchAll(db)
        }
        self.ruuviTagDataTransactionObserver = try! observation.start(in: sqlite.database.dbPool) { [weak self] records in
            self?.subject.send(records.map({ $0.any }))
        }

        let results = self.realm.main.objects(RuuviTagDataRealm.self)
                          .filter("ruuviTag.uuid == %@", ruuviTagId)
                          .sorted(byKeyPath: "date")
        self.ruuviTagDataRealmCache = results.compactMap({ $0.any })
        self.ruuviTagDataRealmToken = results.observe { [weak self] (change) in
            guard let sSelf = self else { return }
            switch change {
            case .initial(let records):
                if records.count > 0 {
                    sSelf.subject.send(records.compactMap({ $0.any }))
                }
            case .update(let records, _, let insertions, _):
                let newRecords = insertions.map({ records[$0] })
                if newRecords.count > 0 {
                    sSelf.subject.send(newRecords.compactMap({ $0.any }))
                }
            default:
                break
            }
        }
    }
}
#endif
