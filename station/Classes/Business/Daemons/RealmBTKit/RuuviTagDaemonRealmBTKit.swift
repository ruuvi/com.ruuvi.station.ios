import BTKit
import RealmSwift

class RuuviTagDaemonRealmBTKit: BackgroundWorker, RuuviTagDaemon {
    
    var ruuviTagPersistence: RuuviTagPersistence!
    var scanner: BTScanner!
    
    private let saveInterval: TimeInterval = 5 * 60
    private var token: NotificationToken?
    private var observeTokens = [ObservationToken]()
    private var realm: Realm!
    private var savedDate = [String:Date]() // uuid:date
    
    @objc private class RuuviTagDaemonPair: NSObject {
        var ruuviTag: RuuviTagRealm
        var device: RuuviTag
        
        init(ruuviTag: RuuviTagRealm, device: RuuviTag) {
            self.ruuviTag = ruuviTag
            self.device = device
        }
    }
    
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
                    let pair = RuuviTagDaemonPair(ruuviTag: ruuviTag, device: tag)
                    sSelf.perform(#selector(RuuviTagDaemonRealmBTKit.tryToUpdate(pair:)),
                                  on: sSelf.thread,
                                  with: pair,
                                  waitUntilDone: false,
                                  modes: [RunLoop.Mode.default.rawValue])
                    sSelf.perform(#selector(RuuviTagDaemonRealmBTKit.persist(pair:)),
                            on: sSelf.thread,
                            with: pair,
                            waitUntilDone: false,
                            modes: [RunLoop.Mode.default.rawValue])
                }
            })
        }
    }
    
    @objc private func tryToUpdate(pair: RuuviTagDaemonPair) {
        if pair.device.version != pair.ruuviTag.version {
            let tagData = RuuviTagDataRealm(ruuviTag: pair.ruuviTag, data: pair.device)
            ruuviTagPersistence.persist(ruuviTagData: tagData, realm: realm)
            ruuviTagPersistence.update(version: pair.device.version, of: pair.ruuviTag, realm: realm)
        }
        if pair.device.mac != nil && pair.device.mac != pair.ruuviTag.mac {
            ruuviTagPersistence.update(mac: pair.device.mac, of: pair.ruuviTag, realm: realm)
        }
    }
    
    @objc private func persist(pair: RuuviTagDaemonPair) {
        let ruuviTagData = RuuviTagDataRealm(ruuviTag: pair.ruuviTag, data: pair.device)
        guard let uuid = ruuviTagData.ruuviTag?.uuid else { return }
        if let date = savedDate[uuid] {
            if Date().timeIntervalSince(date) > saveInterval {
                ruuviTagPersistence.persist(ruuviTagData: ruuviTagData, realm: realm)
                savedDate[uuid] = Date()
            }
        } else {
            ruuviTagPersistence.persist(ruuviTagData: ruuviTagData, realm: realm)
            savedDate[uuid] = Date()
        }
    }
    
    deinit {
        observeTokens.forEach( { $0.invalidate() })
        observeTokens.removeAll()
        token?.invalidate()
    }
}
