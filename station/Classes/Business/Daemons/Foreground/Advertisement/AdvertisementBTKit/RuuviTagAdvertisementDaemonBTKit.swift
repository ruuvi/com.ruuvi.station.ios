import BTKit
import RealmSwift

class RuuviTagAdvertisementDaemonBTKit: BackgroundWorker, RuuviTagAdvertisementDaemon {
    
    var ruuviTagPersistence: RuuviTagPersistence!
    var foreground: BTForeground!
    var settings: Settings!
    
    private var token: NotificationToken?
    private var observeTokens = [ObservationToken]()
    private var realm: Realm!
    private var savedDate = [String:Date]() // uuid:date
    private var isOnToken: NSObjectProtocol?
    private var saveInterval: TimeInterval {
        return TimeInterval(settings.advertisementDaemonIntervalMinutes * 60)
    }
    
    @objc private class RuuviTagDaemonPair: NSObject {
        var ruuviTag: RuuviTagRealm
        var device: RuuviTag
        
        init(ruuviTag: RuuviTagRealm, device: RuuviTag) {
            self.ruuviTag = ruuviTag
            self.device = device
        }
    }
    
    deinit {
        observeTokens.forEach( { $0.invalidate() })
        observeTokens.removeAll()
        token?.invalidate()
        if let isOnToken = isOnToken {
            NotificationCenter.default.removeObserver(isOnToken)
        }
    }
    
    override init() {
        super.init()
        isOnToken = NotificationCenter.default.addObserver(forName: .isAdvertisementDaemonOnDidChange, object: nil, queue: .main) { [weak self] _ in
            guard let sSelf = self else { return }
            if sSelf.settings.isAdvertisementDaemonOn {
                sSelf.start()
            } else {
                sSelf.stop()
            }
        }
    }
    
    func start() {
        start { [weak self] in
            self?.realm = try! Realm()
            
            self?.token = self?.realm.objects(RuuviTagRealm.self).observe({ [weak self] (change) in
                switch change {
                case .initial(let ruuviTags):
                    self?.startObserving(ruuviTags: ruuviTags)
                case .update(let ruuviTags, _, _, _):
                    self?.startObserving(ruuviTags: ruuviTags)
                case .error(let error):
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .RuuviTagAdvertisementDaemonDidFail, object: nil, userInfo: [RuuviTagAdvertisementDaemonDidFailKey.error: RUError.persistence(error)])
                    }
                }
            })
        }
    }
    
    func stop() {
        observeTokens.forEach( { $0.invalidate() })
        observeTokens.removeAll()
        token?.invalidate()
        stopWork()
    }
    
    private func startObserving(ruuviTags: Results<RuuviTagRealm>) {
        observeTokens.forEach( { $0.invalidate() })
        observeTokens.removeAll()
        for ruuviTag in ruuviTags {
            observeTokens.append(foreground.observe(self, uuid: ruuviTag.uuid, options: [.callbackQueue(.untouch)]) { [weak self] (observer, device) in
                guard let sSelf = self else { return }
                if let tag = device.ruuvi?.tag {
                    let pair = RuuviTagDaemonPair(ruuviTag: ruuviTag, device: tag)
                    sSelf.perform(#selector(RuuviTagAdvertisementDaemonBTKit.tryToUpdate(pair:)),
                                  on: sSelf.thread,
                                  with: pair,
                                  waitUntilDone: false,
                                  modes: [RunLoop.Mode.default.rawValue])
                    sSelf.perform(#selector(RuuviTagAdvertisementDaemonBTKit.persist(pair:)),
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
            ruuviTagPersistence.persist(ruuviTagData: tagData, realm: realm).on( failure: { error in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .RuuviTagAdvertisementDaemonDidFail, object: nil, userInfo: [RuuviTagAdvertisementDaemonDidFailKey.error: error])
                }
            })
            ruuviTagPersistence.update(version: pair.device.version, of: pair.ruuviTag, realm: realm).on( failure: { error in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .RuuviTagAdvertisementDaemonDidFail, object: nil, userInfo: [RuuviTagAdvertisementDaemonDidFailKey.error: error])
                }
            })
        }
        if pair.device.mac != nil && pair.device.mac != pair.ruuviTag.mac {
            ruuviTagPersistence.update(mac: pair.device.mac, of: pair.ruuviTag, realm: realm).on( failure: { error in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .RuuviTagAdvertisementDaemonDidFail, object: nil, userInfo: [RuuviTagAdvertisementDaemonDidFailKey.error: error])
                }
            })
        }
    }
    
    @objc private func persist(pair: RuuviTagDaemonPair) {
        let ruuviTagData = RuuviTagDataRealm(ruuviTag: pair.ruuviTag, data: pair.device)
        let uuid = pair.device.uuid
        if let date = savedDate[uuid] {
            if Date().timeIntervalSince(date) > saveInterval {
                ruuviTagPersistence.persist(ruuviTagData: ruuviTagData, realm: realm).on( failure: { error in
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .RuuviTagAdvertisementDaemonDidFail, object: nil, userInfo: [RuuviTagAdvertisementDaemonDidFailKey.error: error])
                    }
                })
                savedDate[uuid] = Date()
            }
        } else {
            ruuviTagPersistence.persist(ruuviTagData: ruuviTagData, realm: realm).on( failure: { error in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .RuuviTagAdvertisementDaemonDidFail, object: nil, userInfo: [RuuviTagAdvertisementDaemonDidFailKey.error: error])
                }
            })
            savedDate[uuid] = Date()
        }
    }
    
}
