import Foundation
import GRDB
import RxSwift
import RealmSwift

class RuuviTagRecordSubjectRxSwift {
    var sqlite: SQLiteContext
    var realm: RealmContext

    let insertSubject: PublishSubject<RuuviTagSensorRecord> = PublishSubject()
    let updateSubject: PublishSubject<RuuviTagSensorRecord> = PublishSubject()
    let deleteSubject: PublishSubject<RuuviTagSensorRecord> = PublishSubject()

    private var ruuviTagDataController: FetchedRecordsController<RuuviTagDataSQLite>
    private var ruuviTagDataRealmToken: NotificationToken?
    private var ruuviTagDataRealmCache = [AnyRuuviTagSensorRecord]()

    deinit {
        ruuviTagDataRealmToken?.invalidate()
        insertSubject.onCompleted()
        updateSubject.onCompleted()
        deleteSubject.onCompleted()
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
                sSelf.insertSubject.onNext(record)
            case .update:
                sSelf.updateSubject.onNext(record)
            case .deletion:
                sSelf.deleteSubject.onNext(record)
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
                    sSelf.deleteSubject.onNext(sSelf.ruuviTagDataRealmCache[del].any)
                }
                sSelf.ruuviTagDataRealmCache = sSelf.ruuviTagDataRealmCache
                                                    .enumerated()
                                                    .filter { !deletions.contains($0.offset) }
                                                    .map { $0.element }
                for ins in insertions {
                    if let record = records[ins].any {
                        sSelf.insertSubject.onNext(record)
                        sSelf.ruuviTagDataRealmCache.insert(record, at: ins) // TODO: test if ok with multiple
                    }
                }
                for mod in modifications {
                    if let record = records[mod].any {
                        sSelf.updateSubject.onNext(record)
                        sSelf.ruuviTagDataRealmCache[mod] = record
                    }
                }
            default:
                break
            }
        }
    }
}
