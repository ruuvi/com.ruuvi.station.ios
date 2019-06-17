import Foundation
import RealmSwift
import BTKit

class RuuviTagDaemonRealmBTKit: RuuviTagDaemon {
    
    var realmContext: RealmContext!
    var ruuviTagPersistence: RuuviTagPersistence!
    
    private var ruuviTagsToken: NotificationToken?
    private let scanner = Ruuvi.scanner
    private var observeTokens = [ObservationToken]()
    
    deinit {
        ruuviTagsToken?.invalidate()
        observeTokens.forEach( { $0.invalidate() })
    }
    
    func startSavingBroadcasts() {
        realmContext.bgWorker.enqueue { [weak self] in
            guard let sSelf = self else { return }
            sSelf.ruuviTagsToken = sSelf.realmContext.bg.objects(RuuviTagRealm.self).observe({ [weak sSelf] (change) in
                guard let ssSelf = sSelf else { return }
                switch change {
                case .initial(let ruuviTags):
                    ssSelf.startObserving(ruuviTags: ruuviTags)
                case .update(let ruuviTags, _, _, _):
                    ssSelf.startObserving(ruuviTags: ruuviTags)
                case .error(let error):
                    print(error.localizedDescription)
                }
            })
        }
    }
    
    func stopSavingBroadcasts() {
        observeTokens.forEach( { $0.invalidate() })
        observeTokens.removeAll()
        ruuviTagsToken?.invalidate()
    }
    
    private func startObserving(ruuviTags: Results<RuuviTagRealm>) {
        observeTokens.forEach( { $0.invalidate() })
        observeTokens.removeAll()
        for ruuviTag in ruuviTags {
            scanner.observe(self, uuid: ruuviTag.uuid, options: [.callbackQueue(.untouch)]) { [weak self] (observer, device) in
                if let tag = device.ruuvi?.tag {
                    self?.ruuviTagPersistence.persist(ruuviTag: ruuviTag, data: tag)
                }
            }
        }
    }
}
