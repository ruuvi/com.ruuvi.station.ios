import Foundation
import BTKit

class RuuviTagPropertiesDaemonBTKit: BackgroundWorker, RuuviTagPropertiesDaemon {

    var ruuviTagTank: RuuviTagTank!
    var ruuviTagReactor: RuuviTagReactor!
    var foreground: BTForeground!
    var idPersistence: IDPersistence!
    var realmPersistence: RuuviTagPersistenceRealm!
    var sqiltePersistence: RuuviTagPersistenceSQLite!

    private var ruuviTagsToken: RUObservationToken?
    private var observeTokens = [ObservationToken]()
    private var ruuviTags = [AnyRuuviTagSensor]()

    @objc private class RuuviTagPropertiesDaemonPair: NSObject {
       var ruuviTag: AnyRuuviTagSensor
       var device: RuuviTag

       init(ruuviTag: AnyRuuviTagSensor, device: RuuviTag) {
           self.ruuviTag = ruuviTag
           self.device = device
       }
    }

    deinit {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        ruuviTagsToken?.invalidate()
    }

    func start() {
       start { [weak self] in
                self?.ruuviTagsToken = self?.ruuviTagReactor.observe({ [weak self] change in
                    guard let sSelf = self else { return }
                    switch change {
                    case .initial(let ruuviTags):
                        sSelf.ruuviTags = ruuviTags
                        sSelf.restartObserving()
                    case .update(let ruuviTag):
                        if let index = sSelf.ruuviTags.firstIndex(of: ruuviTag) {
                            sSelf.ruuviTags[index] = ruuviTag
                        }
                        sSelf.restartObserving()
                    case .insert(let ruuviTag):
                        sSelf.ruuviTags.append(ruuviTag)
                        sSelf.restartObserving()
                    case .delete(let ruuviTag):
                        sSelf.ruuviTags.removeAll(where: { $0.id == ruuviTag.id })
                        sSelf.restartObserving()
                    case .error(let error):
                        sSelf.post(error: RUError.persistence(error))
                    }
                })
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
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        ruuviTagsToken?.invalidate()
        stopWork()
    }

    private func restartObserving() {
       observeTokens.forEach({ $0.invalidate() })
       observeTokens.removeAll()
        for ruuviTag in ruuviTags {
            guard let luid = ruuviTag.luid else { return }
            observeTokens.append(foreground.observe(self,
                                                    uuid: luid.value,
                                                    options: [.callbackQueue(.untouch)]) {
                                                        [weak self] (_, device) in
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

    @objc private func tryToUpdate(pair: RuuviTagPropertiesDaemonPair) {
        if let mac = pair.device.mac, mac != pair.ruuviTag.macId?.value {
            // this is the case when data format 3 tag (2.5.9) changes format
            // either by pressing B or by upgrading firmware
            if let mac = idPersistence.mac(for: pair.device.uuid.luid) {
                // tag is already saved to SQLite
                ruuviTagTank.update(pair.ruuviTag.with(macId: mac))
                    .on(failure: { [weak self] error in
                        self?.post(error: error)
                    })
            } else {
                idPersistence.set(mac: mac.mac, for: pair.device.uuid.luid)
                // now we need to remove the tag from Realm and add it to SQLite
                sqiltePersistence.create(pair.ruuviTag.with(macId: mac.mac)).on(success: { [weak self] _ in
                    self?.realmPersistence.delete(pair.ruuviTag.withoutMac()).on(failure: { error in
                        self?.post(error: error)
                    })
                }, failure: { [weak self] (error) in
                    self?.post(error: error)
                })
            }
        } else if pair.ruuviTag.macId?.value != nil, pair.device.mac == nil {
            // this is the case when 2.5.9 tag is returning to data format 3 mode
            // but we have it in sqlite database already
            if let mac = idPersistence.mac(for: pair.device.uuid.luid) {
                ruuviTagTank.update(pair.ruuviTag.with(macId: mac))
                    .on(failure: { [weak self] error in
                        self?.post(error: error)
                    })
            } else {
                assertionFailure("Should never be there")
            }
        }

        // version and isConnectable change is allowed only when
        // the tag is in SQLite and has MAC
        if let mac = idPersistence.mac(for: pair.device.uuid.luid) {
            if pair.device.version != pair.ruuviTag.version {
                ruuviTagTank.update(pair.ruuviTag.with(version: pair.device.version).with(macId: mac))
                    .on(failure: { [weak self] error in
                        self?.post(error: error)
                    })
            }
            // ignore switch to not connectable state
            if !pair.device.isConnected,
               pair.device.isConnectable != pair.ruuviTag.isConnectable,
               pair.device.isConnectable {
                ruuviTagTank.update(pair.ruuviTag.with(isConnectable: pair.device.isConnectable).with(macId: mac))
                    .on(failure: { [weak self] error in
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
