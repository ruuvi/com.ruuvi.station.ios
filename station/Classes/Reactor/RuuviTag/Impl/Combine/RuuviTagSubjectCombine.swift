#if canImport(Combine)
import Foundation
import GRDB
import Combine
import RealmSwift

@available(iOS 13, *)
class RuuviTagSubjectCombine {
    var sqlite: SQLiteContext
    var realm: RealmContext

    let insertSubject = PassthroughSubject<RuuviTagSensor, Never>()
    let updateSubject = PassthroughSubject<RuuviTagSensor, Never>()
    let deleteSubject = PassthroughSubject<RuuviTagSensor, Never>()

    private var ruuviTagController: FetchedRecordsController<RuuviTagSQLite>
    private var ruuviTagsRealmToken: NotificationToken?

    deinit {
        ruuviTagsRealmToken?.invalidate()
    }

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

        ruuviTagsRealmToken = self.realm.main.objects(RuuviTagRealm.self).observe { [weak self] (change) in
            guard let sSelf = self else { return }
            switch change {
            case .update(let ruuviTags, let deletions, let insertions, let modifications):
                for del in deletions {
                    sSelf.deleteSubject.send(ruuviTags[del])
                }
                for ins in insertions {
                    sSelf.insertSubject.send(ruuviTags[ins])
                }
                for mod in modifications {
                    sSelf.updateSubject.send(ruuviTags[mod])
                }
            default:
                break
            }
        }
    }
}
#endif
