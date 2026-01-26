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
        let ruuviTag = pair.ruuviTag
        let deviceMac = pair.device.mac
        let deviceLuid = pair.device.uuid.luid
        let deviceVersion = pair.device.version
        let existingMacValue = ruuviTag.macId?.value
        let existingVersion = ruuviTag.version

        if let deviceMac, deviceMac != existingMacValue {
            // this is the case when data format 3 tag (2.5.9) changes format
            // either by pressing B or by upgrading firmware
            Task { [weak self] in
                guard let self else { return }
                if let mac = await idPersistence.mac(for: deviceLuid) {
                    // tag is already saved to SQLite
                    do {
                        _ = try await ruuviPool.update(
                            ruuviTag
                                .with(macId: mac)
                                .with(version: deviceVersion)
                        )
                    } catch let error as RuuviPoolError {
                        handlePoolFailure(error, ruuviTag: ruuviTag)
                    }
                }
            }
        } else if existingMacValue != nil, deviceMac == nil {
            // this is the case when 2.5.9 tag is returning to data format 3 mode
            // but we have it in sqlite database already
            Task { [weak self] in
                guard let self else { return }
                if let mac = await idPersistence.mac(for: deviceLuid),
                   deviceVersion != existingVersion {
                    do {
                        _ = try await ruuviPool.update(
                            ruuviTag
                                .with(macId: mac)
                                .with(version: deviceVersion)
                        )
                    } catch let error as RuuviPoolError {
                        handlePoolFailure(error, ruuviTag: ruuviTag)
                    }
                }
            }
        } else {
            if deviceVersion != existingVersion {
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        _ = try await ruuviPool.update(
                            ruuviTag
                                .with(version: deviceVersion)
                        )
                    } catch let error as RuuviPoolError {
                        handlePoolFailure(error, ruuviTag: ruuviTag)
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
            let idPersistence = observer.idPersistence
            let ruuviPool = observer.ruuviPool
            let sqiltePersistence = observer.sqiltePersistence
            Task {
                let existingLuid = await idPersistence.luid(for: macId)
                guard existingLuid?.any != luid.any else { return }
                await idPersistence.set(luid: luid, for: macId)
                if let sensor = try? await sqiltePersistence.readOne(macId.mac) {
                    _ = try? await ruuviPool.update(sensor.with(luid: luid))
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
            let deviceLuid = device.uuid.luid
            let tagUuid = tag.uuid
            Task { [weak sSelf] in
                guard let sSelf else { return }
                defer {
                    sSelf.processingUUIDs.remove(tagUuid)
                }
                await sSelf.idPersistence.set(mac: mac, for: deviceLuid)
                await sSelf.idPersistence.set(luid: deviceLuid, for: mac)
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
