import Foundation
import GRDB
import RxSwift
import RealmSwift
import RuuviOntology
import RuuviContext
#if canImport(RuuviOntologyRealm)
import RuuviOntologyRealm
#endif
#if canImport(RuuviOntologySQLite)
import RuuviOntologySQLite
#endif

class RuuviTagSubjectRxSwift {
    var sqlite: SQLiteContext
    var realm: RealmContext

    let insertSubject: PublishSubject<AnyRuuviTagSensor> = PublishSubject()
    let updateSubject: PublishSubject<AnyRuuviTagSensor> = PublishSubject()
    let deleteSubject: PublishSubject<AnyRuuviTagSensor> = PublishSubject()

    private var ruuviTagController: FetchedRecordsController<RuuviTagSQLite>
    private var ruuviTagsRealmToken: NotificationToken?
    private var ruuviTagRealmCache = [AnyRuuviTagSensor]()

    deinit {
        ruuviTagsRealmToken?.invalidate()
        insertSubject.onCompleted()
        updateSubject.onCompleted()
        deleteSubject.onCompleted()
    }

    // swiftlint:disable:next cyclomatic_complexity
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
                sSelf.insertSubject.onNext(record.any)
            case .update:
                sSelf.updateSubject.onNext(record.any)
            case .deletion:
                sSelf.deleteSubject.onNext(record.any)
            case .move:
                break
            }
        })

        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            let results = sSelf.realm.main.objects(RuuviTagRealm.self)
            sSelf.ruuviTagRealmCache = results.map({ $0.any })
            sSelf.ruuviTagsRealmToken = results.observe { [weak self] (change) in
                guard let sSelf = self else { return }
                switch change {
                case .update(let ruuviTags, let deletions, let insertions, let modifications):
                    for del in deletions {
                        sSelf.deleteSubject.onNext(sSelf.ruuviTagRealmCache[del].any)
                    }
                    sSelf.ruuviTagRealmCache = sSelf.ruuviTagRealmCache
                        .enumerated()
                        .filter { !deletions.contains($0.offset) }
                        .map { $0.element }
                    for ins in insertions {
                        sSelf.insertSubject.onNext(ruuviTags[ins].any)
                        sSelf.ruuviTagRealmCache.insert(ruuviTags[ins].any, at: ins) // TODO: test if ok with multiple
                    }
                    for mod in modifications {
                        sSelf.updateSubject.onNext(ruuviTags[mod].any)
                        sSelf.ruuviTagRealmCache[mod] = ruuviTags[mod].any
                    }
                default:
                    break
                }
            }
        }
    }
}
