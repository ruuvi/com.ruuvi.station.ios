import Foundation
import BTKit
import RuuviOntology
import RuuviReactor
import RuuviPersistence
import RuuviLocal
import RuuviPool

class RuuviTagPropertiesDaemonBTKit: BackgroundWorker, RuuviTagPropertiesDaemon {

    var ruuviPool: RuuviPool!
    var ruuviReactor: RuuviReactor!
    var foreground: BTForeground!
    var idPersistence: RuuviLocalIDs!
    var realmPersistence: RuuviPersistence!
    var sqiltePersistence: RuuviPersistence!

    private var ruuviTagsToken: RuuviReactorToken?
    private var observeTokens = [ObservationToken]()
    private var scanTokens = [ObservationToken]()
    private var ruuviTags = [AnyRuuviTagSensor]()
    private var isTransitioningFromRealmToSQLite = false
    private var processingUUIDs = Set<String>()

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
        scanTokens.forEach({ $0.invalidate() })
        scanTokens.removeAll()
        ruuviTagsToken?.invalidate()
    }

    func start() {
        start { [weak self] in
            self?.ruuviTagsToken = self?.ruuviReactor.observe({ [weak self] change in
                guard let sSelf = self else { return }
                switch change {
                case .initial(let ruuviTags):
                    sSelf.ruuviTags = ruuviTags
                    sSelf.restartObserving()
                case .update(let ruuviTag):
                    if let index = sSelf.ruuviTags
                        .firstIndex(
                            where: {
                                ($0.macId != nil && $0.macId?.any == ruuviTag.macId?.any)
                                || ($0.luid != nil && $0.luid?.any == ruuviTag.luid?.any)
                            }) {
                        sSelf.ruuviTags[index] = ruuviTag
                    }
                    sSelf.restartObserving()
                case .insert(let ruuviTag):
                    sSelf.ruuviTags.append(ruuviTag)
                    sSelf.restartObserving()
                case .delete(let ruuviTag):
                    sSelf.ruuviTags.removeAll(where: {
                        ($0.macId != nil && $0.macId?.any == ruuviTag.macId?.any)
                        || ($0.luid != nil && $0.luid?.any == ruuviTag.luid?.any)
                    })
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
        removeTokens()
        ruuviTagsToken?.invalidate()
        stopWork()
    }

    private func removeTokens() {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        scanTokens.forEach({ $0.invalidate() })
        scanTokens.removeAll()
    }

    private func restartObserving() {
        removeTokens()
        for ruuviTag in ruuviTags {
            if let luid = ruuviTag.luid {
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
            } else if ruuviTag.isCloud {
                scanRemoteSensor(ruuviTag: ruuviTag)
            }
        }
    }

    @objc private func tryToUpdate(pair: RuuviTagPropertiesDaemonPair) {
        if let mac = pair.device.mac, mac != pair.ruuviTag.macId?.value {
            // this is the case when data format 3 tag (2.5.9) changes format
            // either by pressing B or by upgrading firmware
            if let mac = idPersistence.mac(for: pair.device.uuid.luid) {
                // tag is already saved to SQLite
                ruuviPool.update(pair.ruuviTag.with(macId: mac))
                    .on(failure: { [weak self] error in
                        self?.post(error: error)
                    })
            } else {
                isTransitioningFromRealmToSQLite = true
                idPersistence.set(mac: mac.mac, for: pair.device.uuid.luid)
                // now we need to remove the tag from Realm and add it to SQLite
                sqiltePersistence.create(pair.ruuviTag.with(macId: mac.mac))
                    .on(success: { [weak self] _ in
                        self?.realmPersistence.deleteAllRecords(pair.device.uuid).on(success: { _ in
                            self?.realmPersistence.delete(pair.ruuviTag.withoutMac())
                                .on(success: { [weak self] _ in
                                    self?.isTransitioningFromRealmToSQLite = false
                                }, failure: { error in
                                    self?.post(error: error)
                                    self?.isTransitioningFromRealmToSQLite = false
                                })
                        }, failure: { error in
                            self?.post(error: error)
                            self?.isTransitioningFromRealmToSQLite = false
                        })
                }, failure: { [weak self] (error) in
                    self?.post(error: error)
                    self?.isTransitioningFromRealmToSQLite = false
                })
            }
        } else if pair.ruuviTag.macId?.value != nil, pair.device.mac == nil {
            // this is the case when 2.5.9 tag is returning to data format 3 mode
            // but we have it in sqlite database already
            if let mac = idPersistence.mac(for: pair.device.uuid.luid) {
                ruuviPool.update(pair.ruuviTag.with(macId: mac))
                    .on(failure: { [weak self] error in
                        self?.post(error: error)
                    })
            } else {
                assertionFailure("Should never be there")
            }
        }

        // while transitioning tag from realm to sqlite - stop operating
        guard !isTransitioningFromRealmToSQLite else { return }

        // version and isConnectable change is allowed only when
        // the tag is in SQLite and has MAC
        if let mac = idPersistence.mac(for: pair.device.uuid.luid) {
            if pair.device.version != pair.ruuviTag.version {
                ruuviPool.update(pair.ruuviTag.with(version: pair.device.version).with(macId: mac))
                    .on(failure: { [weak self] error in
                        self?.post(error: error)
                    })
            }
            // ignore switch to not connectable state
            if !pair.device.isConnected,
               pair.device.isConnectable != pair.ruuviTag.isConnectable,
               pair.device.isConnectable {
                ruuviPool.update(pair.ruuviTag.with(isConnectable: pair.device.isConnectable).with(macId: mac))
                    .on(failure: { [weak self] error in
                        self?.post(error: error)
                    })
            }
        }
    }

    private func scanRemoteSensor(ruuviTag: AnyRuuviTagSensor) {
        guard let mac = ruuviTag.macId,
              ruuviTag.luid == nil else {
            return
        }
        let scanToken = foreground.scan(self, closure: { [weak self] (_, device) in
            guard let sSelf = self,
                  let tag = device.ruuvi?.tag,
                  mac.any == tag.macId?.any,
                  ruuviTag.luid == nil,
                  !sSelf.processingUUIDs.contains(tag.uuid) else {
                return
            }
            sSelf.processingUUIDs.insert(tag.uuid)
            let ruuviSensor = RuuviTagSensorStruct(
                version: tag.version,
                luid: device.uuid.luid,
                macId: mac,
                isConnectable: device.isConnectable,
                name: ruuviTag.name,
                isClaimed: ruuviTag.isClaimed,
                isOwner: ruuviTag.isClaimed,
                owner: ruuviTag.owner)
            sSelf.idPersistence.set(mac: mac, for: device.uuid.luid)
            sSelf.idPersistence.set(luid: device.uuid.luid, for: mac)
            sSelf.ruuviPool.update(ruuviSensor)
                .on(failure: { [weak sSelf] error in
                    sSelf?.post(error: error)
                }, completion: { [weak sSelf] in
                    sSelf?.processingUUIDs.remove(tag.uuid)
                })
        })
        scanTokens.append(scanToken)
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
