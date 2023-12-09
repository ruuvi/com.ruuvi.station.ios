import Combine
import Foundation
import GRDB
import RealmSwift
import RuuviContext
import RuuviOntology
#if canImport(RuuviOntologyRealm)
    import RuuviOntologyRealm
#endif
#if canImport(RuuviOntologySQLite)
    import RuuviOntologySQLite
#endif

final class RuuviTagRecordSubjectCombine {
    var isServing: Bool = false

    private var sqlite: SQLiteContext
    private var realm: RealmContext
    private var luid: LocalIdentifier?
    private var macId: MACIdentifier?

    let subject = PassthroughSubject<[AnyRuuviTagSensorRecord], Never>()

    private var ruuviTagDataRealmToken: NotificationToken?
    private var ruuviTagDataRealmCache = [AnyRuuviTagSensorRecord]()
    private var ruuviTagDataTransactionObserver: TransactionObserver?
    deinit {
        ruuviTagDataRealmToken?.invalidate()
    }

    init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        sqlite: SQLiteContext,
        realm: RealmContext
    ) {
        self.sqlite = sqlite
        self.realm = realm
        self.luid = luid
        self.macId = macId
    }

    func start() {
        isServing = true
        let request = RuuviTagDataSQLite.order(RuuviTagDataSQLite.dateColumn)
            .filter(
                (luid?.value != nil && RuuviTagDataSQLite.luidColumn == luid?.value)
                    || (macId?.value != nil && RuuviTagDataSQLite.macColumn == macId?.value)
            )
        let observation = ValueObservation.tracking { db -> [RuuviTagDataSQLite] in
            try! request.fetchAll(db)
        }.removeDuplicates()

        ruuviTagDataTransactionObserver = try! observation.start(in: sqlite.database.dbPool) {
            [weak self] records in
            self?.subject.send(records.map(\.any))
        }

        let results = realm.main.objects(RuuviTagDataRealm.self)
            .filter("ruuviTag.uuid == %@ || ruuviTag.mac == %@",
                    luid?.value ?? "invalid",
                    macId?.value ?? "invalid")
            .sorted(byKeyPath: "date")
        ruuviTagDataRealmCache = results.compactMap(\.any)
        ruuviTagDataRealmToken = results.observe { [weak self] change in
            guard let sSelf = self else { return }
            switch change {
            case let .initial(records):
                if records.count > 0 {
                    sSelf.subject.send(records.compactMap(\.any))
                }
            case let .update(records, _, _, _):
                if records.count > 0 {
                    sSelf.subject.send(records.compactMap(\.any))
                }
            default:
                break
            }
        }
    }
}
