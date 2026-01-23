import BTKit
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviReactor

public final class RuuviTagPropertiesDaemonBTKit: RuuviDaemonWorker, RuuviTagPropertiesDaemon {
    private let ruuviPool: RuuviPool
    private let ruuviReactor: RuuviReactor
    private let foreground: BTForeground
    private let idPersistence: RuuviLocalIDs
    private let sqiltePersistence: RuuviPersistence

    public init(
        ruuviPool: RuuviPool,
        ruuviReactor: RuuviReactor,
        foreground: BTForeground,
        idPersistence: RuuviLocalIDs,
        sqiltePersistence: RuuviPersistence
    ) {
        self.ruuviPool = ruuviPool
        self.ruuviReactor = ruuviReactor
        self.foreground = foreground
        self.idPersistence = idPersistence
        self.sqiltePersistence = sqiltePersistence
        super.init()
    }

    private var ruuviTagsToken: RuuviReactorToken?
    private var observeTokens = [ObservationToken]()
    private var scanTokens = [ObservationToken]()
    private var ruuviTags = [AnyRuuviTagSensor]()
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
        observeTokens.forEach { $0.invalidate() }
        observeTokens.removeAll()
        scanTokens.forEach { $0.invalidate() }
        scanTokens.removeAll()
        ruuviTagsToken?.invalidate()
    }

    public func start() {
        start { [weak self] in
            self?.ruuviTagsToken = self?.ruuviReactor.observe { [weak self] change in
                guard let sSelf = self else { return }
                switch change {
                case let .initial(ruuviTags):
                    sSelf.ruuviTags = ruuviTags
                    if !ruuviTags.isEmpty {
                        sSelf.restartObserving()
                    }
                case let .update(ruuviTag):
                    if let index = sSelf.ruuviTags
                        .firstIndex(
                            where: {
                                ($0.macId != nil && $0.macId?.any == ruuviTag.macId?.any)
                                    || ($0.luid != nil && $0.luid?.any == ruuviTag.luid?.any)
                            }) {
                        sSelf.ruuviTags[index] = ruuviTag
                    }
                    sSelf.restartObserving()
                case let .insert(ruuviTag):
                    sSelf.ruuviTags.append(ruuviTag)
                    sSelf.restartObserving()
                case let .delete(ruuviTag):
                    sSelf.ruuviTags.removeAll(where: {
                        ($0.macId != nil && $0.macId?.any == ruuviTag.macId?.any)
                            || ($0.luid != nil && $0.luid?.any == ruuviTag.luid?.any)
                    })
                    sSelf.restartObserving()
                case let .error(error):
                    sSelf.post(error: .ruuviReactor(error))
                }
            }
        }
    }

    public func stop() {
        perform(
            #selector(RuuviTagPropertiesDaemonBTKit.stopDaemon),
            on: thread,
            with: nil,
            waitUntilDone: false,
            modes: [RunLoop.Mode.default.rawValue]
        )
    }

    @objc private func stopDaemon() {
        removeTokens()
        ruuviTagsToken?.invalidate()
        stopWork()
    }

    private func removeTokens() {
        observeTokens.forEach { $0.invalidate() }
        observeTokens.removeAll()
        scanTokens.forEach { $0.invalidate() }
        scanTokens.removeAll()
    }

    private func restartObserving() {
        removeTokens()
        listenToUuidChangesForMac()
        for ruuviTag in ruuviTags {
            if let luid = ruuviTag.luid {
                observeTokens.append(foreground.observe(
                    self,
                    uuid: luid.value,
                    options: [.callbackQueue(.untouch)]
                ) {
                    [weak self] _, device in
                    guard let sSelf = self, sSelf.thread != nil else { return }
                    if let tag = device.ruuvi?.tag {
                        let pair = RuuviTagPropertiesDaemonPair(ruuviTag: ruuviTag, device: tag)
                        sSelf.perform(
                            #selector(RuuviTagPropertiesDaemonBTKit.tryToUpdate(pair:)),
                            on: sSelf.thread,
                            with: pair,
                            waitUntilDone: false,
                            modes: [RunLoop.Mode.default.rawValue]
                        )
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
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        _ = try await ruuviPool.update(
                            pair.ruuviTag
                                .with(macId: mac)
                                .with(version: pair.device.version)
                        )
                    } catch let error as RuuviPoolError {
                        handlePoolFailure(error, ruuviTag: pair.ruuviTag)
                    }
                }
            }
        } else if pair.ruuviTag.macId?.value != nil, pair.device.mac == nil {
            // this is the case when 2.5.9 tag is returning to data format 3 mode
            // but we have it in sqlite database already
            if let mac = idPersistence.mac(for: pair.device.uuid.luid),
               pair.device.version != pair.ruuviTag.version {
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        _ = try await ruuviPool.update(
                            pair.ruuviTag
                                .with(macId: mac)
                                .with(version: pair.device.version)
                        )
                    } catch let error as RuuviPoolError {
                        handlePoolFailure(error, ruuviTag: pair.ruuviTag)
                    }
                }
            }
        } else {
            if pair.device.version != pair.ruuviTag.version {
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        _ = try await ruuviPool.update(
                            pair.ruuviTag
                                .with(version: pair.device.version)
                        )
                    } catch let error as RuuviPoolError {
                        handlePoolFailure(error, ruuviTag: pair.ruuviTag)
                    }
                }
            }
        }
    }

    private func listenToUuidChangesForMac() {
        let scanToken = foreground.scan(self, closure: { observer, device in
            guard let tag = device.ruuvi?.tag,
                  let luid = tag.luid,
                  let macId = tag.macId
            else {
                return
            }
            if observer.idPersistence.luid(for: macId)?.any != luid.any {
                observer.idPersistence.set(luid: luid, for: macId)
                Task { [weak observer] in
                    guard let observer else { return }
                    if let sensor = try? await observer.sqiltePersistence.readOne(macId.mac) {
                        _ = try? await observer.ruuviPool.update(sensor.with(luid: luid))
                    }
                }
            }
        })
        scanTokens.append(scanToken)
    }

    private func scanRemoteSensor(ruuviTag: AnyRuuviTagSensor) {
        guard let mac = ruuviTag.macId,
              ruuviTag.luid == nil
        else {
            return
        }
        let scanToken = foreground.scan(self, closure: { [weak self] _, device in
            guard let sSelf = self,
                  let tag = device.ruuvi?.tag,
                  mac.any == tag.macId?.any,
                  ruuviTag.luid == nil || ruuviTag.serviceUUID == nil,
                  !sSelf.processingUUIDs.contains(tag.uuid)
            else {
                return
            }
            sSelf.processingUUIDs.insert(tag.uuid)
            let ruuviSensor = RuuviTagSensorStruct(
                version: tag.version,
                firmwareVersion: ruuviTag.firmwareVersion,
                luid: device.uuid.luid,
                macId: mac,
                serviceUUID: device.serviceUUID,
                isConnectable: device.isConnectable,
                name: ruuviTag.name,
                isClaimed: ruuviTag.isClaimed,
                isOwner: ruuviTag.isOwner,
                owner: ruuviTag.owner,
                ownersPlan: ruuviTag.ownersPlan,
                isCloudSensor: ruuviTag.isCloudSensor,
                canShare: ruuviTag.canShare,
                sharedTo: ruuviTag.sharedTo,
                maxHistoryDays: ruuviTag.maxHistoryDays
            )
            sSelf.idPersistence.set(mac: mac, for: device.uuid.luid)
            sSelf.idPersistence.set(luid: device.uuid.luid, for: mac)
            Task { [weak sSelf] in
                guard let sSelf else { return }
                defer {
                    sSelf.processingUUIDs.remove(tag.uuid)
                }
                do {
                    _ = try await sSelf.ruuviPool.update(ruuviSensor)
                } catch let error as RuuviPoolError {
                    sSelf.handlePoolFailure(error, ruuviTag: ruuviSensor)
                }
            }
        })
        scanTokens.append(scanToken)
    }

    private func post(error: RuuviDaemonError) {
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(
                    name: .RuuviTagPropertiesDaemonDidFail,
                    object: nil,
                    userInfo: [RuuviTagPropertiesDaemonDidFailKey.error: error]
                )
        }
    }

    private func handlePoolFailure(
        _ error: RuuviPoolError,
        ruuviTag: RuuviTagSensor
    ) {
        if case let .ruuviPersistence(persistenceError) = error,
           case .failedToFindRuuviTag = persistenceError {
            removeCachedSensor(matching: ruuviTag)
            restartObserving()
            return
        }
        post(error: .ruuviPool(error))
    }

    private func removeCachedSensor(matching ruuviTag: RuuviTagSensor) {
        ruuviTags.removeAll(where: {
            ($0.macId != nil && $0.macId?.any == ruuviTag.macId?.any)
                || ($0.luid != nil && $0.luid?.any == ruuviTag.luid?.any)
        })
    }
}
