import BTKit
import Foundation
import RealmSwift

class RuuviTagPropertiesDaemonBTKit: BackgroundWorker, RuuviTagPropertiesDaemon {

    var ruuviTagPersistence: RuuviTagPersistence!
    var foreground: BTForeground!

    private var token: NotificationToken?
    private var observeTokens = [ObservationToken]()
    private var realm: Realm!

    @objc private class RuuviTagPropertiesDaemonPair: NSObject {
       var ruuviTag: RuuviTagRealm
       var device: RuuviTag

       init(ruuviTag: RuuviTagRealm, device: RuuviTag) {
           self.ruuviTag = ruuviTag
           self.device = device
       }
    }

    deinit {
        autoreleasepool {
            observeTokens.forEach({ $0.invalidate() })
            observeTokens.removeAll()
            token?.invalidate()
        }
    }

    func start() {
       start { [weak self] in
            autoreleasepool {
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
    }

    func stop() {
        perform(#selector(RuuviTagPropertiesDaemonBTKit.stopDaemon),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
    }

    @objc private func stopDaemon() {
        autoreleasepool {
            observeTokens.forEach({ $0.invalidate() })
            observeTokens.removeAll()
            token?.invalidate()
            realm.invalidate()
            stopWork()
        }
    }

    private func startObserving(ruuviTags: Results<RuuviTagRealm>) {
       observeTokens.forEach({ $0.invalidate() })
       observeTokens.removeAll()
        autoreleasepool {
            for ruuviTag in ruuviTags {
                observeTokens.append(foreground.observe(self,
                                                        uuid: ruuviTag.uuid,
                                                        options: [.callbackQueue(.untouch)]) { [weak self] (_, device) in
                    guard let sSelf = self else { return }
                    if let tag = device.ruuvi?.tag {
                        let pair = RuuviTagPropertiesDaemonPair(ruuviTag: ruuviTag, device: tag)
                        sSelf.perform(#selector(RuuviTagPropertiesDaemonBTKit.tryToUpdate(pair:)),
                                      on: sSelf.thread,
                                      with: pair,
                                      waitUntilDone: false,
                                      modes: [RunLoop.Mode.default.rawValue])
                    }
                })
            }
        }
    }

    @objc private func tryToUpdate(pair: RuuviTagPropertiesDaemonPair) {
        autoreleasepool {
            if pair.device.version != pair.ruuviTag.version {
                let tagData = RuuviTagDataRealm(ruuviTag: pair.ruuviTag, data: pair.device)
                ruuviTagPersistence.persist(ruuviTagData: tagData, realm: realm).on( failure: { [weak self] error in
                    self?.post(error: error)
                })
                ruuviTagPersistence.update(version: pair.device.version,
                                           of: pair.ruuviTag, realm: realm)
                 .on( failure: { [weak self] error in
                    self?.post(error: error)
                })
            }
            if pair.device.mac != nil && pair.device.mac != pair.ruuviTag.mac {
                ruuviTagPersistence.update(mac: pair.device.mac, of: pair.ruuviTag, realm: realm)
                 .on( failure: { [weak self] error in
                    self?.post(error: error)
                })
            }
            if pair.device.isConnectable != pair.ruuviTag.isConnectable {
                ruuviTagPersistence.update(isConnectable: pair.device.isConnectable, of: pair.ruuviTag, realm: realm)
                 .on( failure: { [weak self] error in
                    self?.post(error: error)
                })
            }
        }
    }

    private func post(error: Error) {
        DispatchQueue.main.async {
            NotificationCenter
             .default
             .post(name: .RuuviTagPropertiesDaemonDidFail,
                   object: nil,
                   userInfo: [RuuviTagPropertiesDaemonDidFailKey.error: error])
        }
    }
}
