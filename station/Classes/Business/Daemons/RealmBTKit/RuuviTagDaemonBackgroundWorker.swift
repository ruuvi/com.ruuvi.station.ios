import BTKit
import RealmSwift

class RuuviTagDaemonBackgroundWorker: BackgroundWorker, RuuviTagDaemon {
    
    var ruuviTagPersistence: RuuviTagPersistence!
    
    private var token: NotificationToken?
    private let scanner = Ruuvi.scanner
    private var observeTokens = [ObservationToken]()
    private var realm: Realm!
    
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
                    sSelf.perform(#selector(RuuviTagDaemonBackgroundWorker.persist(ruuviTagData:)),
                            on: sSelf.thread,
                            with: tagData,
                            waitUntilDone: false,
                            modes: [RunLoop.Mode.default.rawValue])
                }
            })
        }
    }
    
    @objc func persist(ruuviTagData: RuuviTagDataRealm) {
        ruuviTagPersistence.persist(ruuviTagData: ruuviTagData, realm: realm)
    }
    
    deinit {
        token?.invalidate()
    }
}
