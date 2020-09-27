#if canImport(Combine)
import Foundation
import Combine
import RealmSwift

@available(iOS 13, *)
class VirtualTagSubjectCombine {
    var realm: RealmContext

    let insertSubject = PassthroughSubject<AnyVirtualTagSensor, Never>()
    let updateSubject = PassthroughSubject<AnyVirtualTagSensor, Never>()
    let deleteSubject = PassthroughSubject<AnyVirtualTagSensor, Never>()

    private var webTagsRealmToken: NotificationToken?
    private var webTagRealmCache = [AnyVirtualTagSensor]()

    deinit {
        webTagsRealmToken?.invalidate()
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
                        sSelf.deleteSubject.send(sSelf.webTagRealmCache[del].any)
                    }
                    sSelf.webTagRealmCache = sSelf.webTagRealmCache
                                                    .enumerated()
                                                    .filter { !deletions.contains($0.offset) }
                                                    .map { $0.element }
                    for ins in insertions {
                        sSelf.insertSubject.send(webTags[ins].any)
                        // TODO: test if ok with multiple
                        sSelf.webTagRealmCache.insert(webTags[ins].any, at: ins)
                    }
                    for mod in modifications {
                        sSelf.updateSubject.send(webTags[mod].any)
                        sSelf.webTagRealmCache[mod] = webTags[mod].any
                    }
                default:
                    break
                }
            }
        }
    }
}
#endif
