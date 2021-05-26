import Foundation
import RxSwift
import RealmSwift
import RuuviOntology

class VirtualTagSubjectRxSwift {
    var realm: RealmContext

    let insertSubject: PublishSubject<AnyVirtualTagSensor> = PublishSubject()
    let updateSubject: PublishSubject<AnyVirtualTagSensor> = PublishSubject()
    let deleteSubject: PublishSubject<AnyVirtualTagSensor> = PublishSubject()

    private var webTagsRealmToken: NotificationToken?
    private var webTagRealmCache = [AnyVirtualTagSensor]()

    deinit {
        webTagsRealmToken?.invalidate()
        insertSubject.onCompleted()
        updateSubject.onCompleted()
        deleteSubject.onCompleted()
    }

    init(realm: RealmContext) {
        self.realm = realm
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            let results = sSelf.realm.main.objects(WebTagRealm.self)
            sSelf.webTagRealmCache = results.map({ $0.any })
            sSelf.webTagsRealmToken = results.observe { [weak self] (change) in
                guard let sSelf = self else { return }
                switch change {
                case .update(let webTags, let deletions, let insertions, let modifications):
                    for del in deletions {
                        sSelf.deleteSubject.onNext(sSelf.webTagRealmCache[del].any)
                    }
                    sSelf.webTagRealmCache = sSelf.webTagRealmCache
                        .enumerated()
                        .filter { !deletions.contains($0.offset) }
                        .map { $0.element }
                    for ins in insertions {
                        sSelf.insertSubject.onNext(webTags[ins].any)
                        sSelf.webTagRealmCache.insert(webTags[ins].any, at: ins) // TODO: test if ok with multiple
                    }
                    for mod in modifications {
                        sSelf.updateSubject.onNext(webTags[mod].any)
                        sSelf.webTagRealmCache[mod] = webTags[mod].any
                    }
                default:
                    break
                }
            }
        }
    }
}
