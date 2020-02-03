import BTKit
import Foundation
import RealmSwift

class RuuviTagAdvertisementDaemonBTKit: BackgroundWorker, RuuviTagAdvertisementDaemon {

    var ruuviTagPersistence: RuuviTagPersistence!
    var foreground: BTForeground!
    var settings: Settings!

    private var token: NotificationToken?
    private var observeTokens = [ObservationToken]()
    private var realm: Realm!
    private var savedDate = [String: Date]() // uuid:date
    private var isOnToken: NSObjectProtocol?
    private var saveInterval: TimeInterval {
        return TimeInterval(settings.advertisementDaemonIntervalMinutes * 60)
    }

    @objc private class RuuviTagAdvertisementDaemonPair: NSObject {
        var ruuviTag: RuuviTagRealm
        var device: RuuviTag

        init(ruuviTag: RuuviTagRealm, device: RuuviTag) {
            self.ruuviTag = ruuviTag
            self.device = device
        }
    }

    deinit {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        token?.invalidate()
        if let isOnToken = isOnToken {
            NotificationCenter.default.removeObserver(isOnToken)
        }
    }

    override init() {
        super.init()
        isOnToken = NotificationCenter
            .default
            .addObserver(forName: .isAdvertisementDaemonOnDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
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
                    self?.post(error: RUError.persistence(error))
                }
            })
        }
    }

    func stop() {
        perform(#selector(RuuviTagAdvertisementDaemonBTKit.stopDaemon),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
    }

    @objc private func stopDaemon() {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        token?.invalidate()
        realm.invalidate()
        stopWork()
    }

    private func startObserving(ruuviTags: Results<RuuviTagRealm>) {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        for ruuviTag in ruuviTags {
            observeTokens.append(foreground.observe(self,
                                                    uuid: ruuviTag.uuid,
                                                    options: [.callbackQueue(.untouch)]) { [weak self] (_, device) in
                guard let sSelf = self else { return }
                if let tag = device.ruuvi?.tag {
                    let pair = RuuviTagAdvertisementDaemonPair(ruuviTag: ruuviTag, device: tag)
                    sSelf.perform(#selector(RuuviTagAdvertisementDaemonBTKit.persist(pair:)),
                            on: sSelf.thread,
                            with: pair,
                            waitUntilDone: false,
                            modes: [RunLoop.Mode.default.rawValue])
                }
            })
        }
    }

    @objc private func persist(pair: RuuviTagAdvertisementDaemonPair) {
        let uuid = pair.device.uuid
        if let date = savedDate[uuid] {
            if Date().timeIntervalSince(date) > saveInterval {
                let ruuviTagData = RuuviTagDataRealm(ruuviTag: pair.ruuviTag, data: pair.device)
                persist(ruuviTagData)
                savedDate[uuid] = Date()
            }
        } else {
            let ruuviTagData = RuuviTagDataRealm(ruuviTag: pair.ruuviTag, data: pair.device)
            persist(ruuviTagData)
            savedDate[uuid] = Date()
        }
    }

    private func persist(_ ruuviTagData: RuuviTagDataRealm) {
        ruuviTagPersistence.persist(ruuviTagData: ruuviTagData, realm: realm).on( failure: { [weak self] error in
            self?.post(error: error)
        })
    }

    private func post(error: Error) {
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(name: .RuuviTagAdvertisementDaemonDidFail,
                      object: nil,
                      userInfo: [RuuviTagAdvertisementDaemonDidFailKey.error: error])
        }
    }
}
