#if canImport(Combine)
import Foundation
import GRDB
import Combine
import RealmSwift

@available(iOS 13, *)
class RuuviTagRecordSubjectCombine {
    var sqlite: SQLiteContext
    var realm: RealmContext

    let insertSubject = PassthroughSubject<RuuviTagSensorRecord, Never>()
    let updateSubject = PassthroughSubject<RuuviTagSensorRecord, Never>()
    let deleteSubject = PassthroughSubject<RuuviTagSensorRecord, Never>()

    private var ruuviTagDataController: FetchedRecordsController<RuuviTagDataSQLite>
    private var ruuviTagDataRealmToken: NotificationToken?
    private var ruuviTagDataRealmCache = [AnyRuuviTagSensorRecord]()

    deinit {
        ruuviTagDataRealmToken?.invalidate()
    }

    init(ruuviTagId: String, sqlite: SQLiteContext, realm: RealmContext) {
        self.sqlite = sqlite
        self.realm = realm

        let request = RuuviTagDataSQLite.order(RuuviTagDataSQLite.dateColumn)
                                        .filter(RuuviTagDataSQLite.ruuviTagIdColumn == ruuviTagId)
        self.ruuviTagDataController = try! FetchedRecordsController(sqlite.database.dbPool, request: request)
        try! self.ruuviTagDataController.performFetch()

        self.ruuviTagDataController.trackChanges(onChange: { [weak self] _, record, event in
            guard let sSelf = self else { return }
            switch event {
            case .insertion:
                sSelf.insertSubject.send(record)
            case .update:
                sSelf.updateSubject.send(record)
            case .deletion:
                sSelf.deleteSubject.send(record)
            case .move:
                break
            }
        })

        let results = self.realm.main.objects(RuuviTagDataRealm.self)
                          .filter("ruuviTag.uuid == %@", ruuviTagId)
                          .sorted(byKeyPath: "date")
        self.ruuviTagDataRealmCache = results.compactMap({ $0.any })
        self.ruuviTagDataRealmToken = results.observe { [weak self] (change) in
            guard let sSelf = self else { return }
            switch change {
            case .update(let records, let deletions, let insertions, let modifications):
                for del in deletions {
                    sSelf.deleteSubject.send(sSelf.ruuviTagDataRealmCache[del].any)
                }
                sSelf.ruuviTagDataRealmCache = sSelf.ruuviTagDataRealmCache
                                                    .enumerated()
                                                    .filter { !deletions.contains($0.offset) }
                                                    .map { $0.element }
                for ins in insertions {
                    if let record = records[ins].any {
                        sSelf.insertSubject.send(record)
                        sSelf.ruuviTagDataRealmCache.insert(record, at: ins) // TODO: test if ok with multiple
                    }
                }
                for mod in modifications {
                    if let record = records[mod].any {
                        sSelf.updateSubject.send(record)
                        sSelf.ruuviTagDataRealmCache[mod] = record
                    }
                }
            default:
                break
            }
        }
    }
}
#endif
