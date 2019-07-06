import BTKit
import RealmSwift

class RuuviTagDaemonRealmBTKit: BackgroundWorker, RuuviTagDaemon {
    
    var ruuviTagPersistence: RuuviTagPersistence!
    
    private let saveInterval: TimeInterval = 10 // 5 * 60
    private var token: NotificationToken?
    private let scanner = Ruuvi.scanner
    private var observeTokens = [ObservationToken]()
    private var realm: Realm!
    private var savedDate = [String:Date]() // uuid:date
    
    func startSavingBroadcasts() {
        start { [weak self] in
            self?.realm = try! Realm()
            
            self?.token = self?.realm.objects(RuuviTagRealm.self).observe({ [weak self] (change) in
                switch change {
                case .initial(let ruuviTags):
                    self?.startObserving(ruuviTags: ruuviTags)
                case .update(let ruuviTags, _, _, _):
                    self?.startObserving(ruuviTags: ruuviTags)
                case .error(let error):
                    print(error.localizedDescription)
                }
            })
        }
    }
    
    func stopSavingBroadcasts() {
        observeTokens.forEach( { $0.invalidate() })
        observeTokens.removeAll()
        token?.invalidate()
        stop()
    }
    
    private func startObserving(ruuviTags: Results<RuuviTagRealm>) {
        observeTokens.forEach( { $0.invalidate() })
        observeTokens.removeAll()
        for ruuviTag in ruuviTags {
            observeTokens.append(scanner.observe(self, uuid: ruuviTag.uuid, options: [.callbackQueue(.untouch)]) { [weak self] (observer, device) in
                guard let sSelf = self else { return }
                if let tag = device.ruuvi?.tag {
                    let tagData = RuuviTagDataRealm(ruuviTag: ruuviTag, data: tag)
                    sSelf.perform(#selector(RuuviTagDaemonRealmBTKit.persist(ruuviTagData:)),
                            on: sSelf.thread,
                            with: tagData,
                            waitUntilDone: false,
                            modes: [RunLoop.Mode.default.rawValue])
                }
            })
        }
    }
    
    @objc func persist(ruuviTagData: RuuviTagDataRealm) {
        if let uuid = ruuviTagData.ruuviTag?.uuid, let date = savedDate[uuid] {
            if Date().timeIntervalSince(date) > saveInterval {
                ruuviTagPersistence.persist(ruuviTagData: ruuviTagData, realm: realm)
                savedDate[uuid] = Date()
            }
        } else {
            ruuviTagPersistence.persist(ruuviTagData: ruuviTagData, realm: realm)
        }
    }
    
    deinit {
        observeTokens.forEach( { $0.invalidate() })
        observeTokens.removeAll()
        token?.invalidate()
    }
}
