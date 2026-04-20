import BTKit
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviReactor

enum RuuviTagPropertiesPoolFailureAction {
    case removeCachedSensor
    case postError(RuuviDaemonError)
}

protocol PropertiesForegrounding {
    @discardableResult
    func observe<T: AnyObject>(
        _ observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        closure: @escaping (T, BTDevice) -> Void
    ) -> DaemonObservationToken

    @discardableResult
    func scan<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, BTDevice) -> Void
    ) -> DaemonObservationToken
}

private struct PropertiesForegroundAdapter: PropertiesForegrounding {
    let foreground: BTForeground

    func observe<T: AnyObject>(
        _ observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        closure: @escaping (T, BTDevice) -> Void
    ) -> DaemonObservationToken {
        let token = foreground.observe(
            observer,
            uuid: uuid,
            options: options,
            closure: closure
        )
        return DaemonObservationToken {
            token.invalidate()
        }
    }

    func scan<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, BTDevice) -> Void
    ) -> DaemonObservationToken {
        let token = foreground.scan(observer, closure: closure)
        return DaemonObservationToken {
            token.invalidate()
        }
    }
}

protocol PropertiesIDPersisting {
    func mac(for luid: LocalIdentifier) -> MACIdentifier?
    func luid(for mac: MACIdentifier) -> LocalIdentifier?
    func set(mac: MACIdentifier, for luid: LocalIdentifier)
    func set(luid: LocalIdentifier, for mac: MACIdentifier)
}

struct PropertiesIDPersistenceAdapter: PropertiesIDPersisting {
    let ids: RuuviLocalIDs

    func mac(for luid: LocalIdentifier) -> MACIdentifier? {
        ids.mac(for: luid)
    }

    func luid(for mac: MACIdentifier) -> LocalIdentifier? {
        ids.luid(for: mac)
    }

    func set(mac: MACIdentifier, for luid: LocalIdentifier) {
        ids.set(mac: mac, for: luid)
    }

    func set(luid: LocalIdentifier, for mac: MACIdentifier) {
        ids.set(luid: luid, for: mac)
    }
}

protocol PropertiesSensorReading {
    func readOne(_ id: String) async throws -> AnyRuuviTagSensor
}

struct PropertiesSensorReaderAdapter: PropertiesSensorReading {
    let persistence: RuuviPersistence

    func readOne(_ id: String) async throws -> AnyRuuviTagSensor {
        try await persistence.readOne(id)
    }
}

struct RuuviTagPropertiesDaemonCore {
    static func updatedSensor(
        current ruuviTag: AnyRuuviTagSensor,
        observed device: RuuviTag,
        persistedMac: MACIdentifier?
    ) -> (any RuuviTagSensor)? {
        if let mac = device.mac, mac != ruuviTag.macId?.value {
            if let persistedMac {
                return ruuviTag
                    .with(macId: persistedMac)
                    .with(version: device.version)
            }
            return nil
        } else if ruuviTag.macId?.value != nil, device.mac == nil {
            if let persistedMac, device.version != ruuviTag.version {
                return ruuviTag
                    .with(macId: persistedMac)
                    .with(version: device.version)
            }
            return nil
        } else if device.version != ruuviTag.version {
            return ruuviTag.with(version: device.version)
        } else {
            return nil
        }
    }

    static func shouldProcessRemoteScan(
        ruuviTag: AnyRuuviTagSensor,
        device: BTDevice,
        processingUUIDs: Set<String>
    ) -> Bool {
        guard let mac = ruuviTag.macId,
              ruuviTag.luid == nil,
              let tag = device.ruuvi?.tag,
              mac.any == tag.macId?.any
        else {
            return false
        }
        return !processingUUIDs.contains(tag.uuid)
    }

    static func makeRemoteSensor(
        from ruuviTag: AnyRuuviTagSensor,
        device: BTDevice
    ) -> RuuviTagSensorStruct? {
        guard let tag = device.ruuvi?.tag,
              let mac = ruuviTag.macId,
              ruuviTag.luid == nil
        else {
            return nil
        }
        return RuuviTagSensorStruct(
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
    }

    static func makeRemoteSensor(
        from ruuviTag: AnyRuuviTagSensor,
        mac: MACIdentifier,
        tag: RuuviTag,
        device: BTDevice
    ) -> RuuviTagSensorStruct {
        RuuviTagSensorStruct(
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
    }

    static func poolFailureAction(
        for error: RuuviPoolError
    ) -> RuuviTagPropertiesPoolFailureAction {
        if case let .ruuviPersistence(persistenceError) = error,
           case .failedToFindRuuviTag = persistenceError {
            return .removeCachedSensor
        }
        return .postError(.ruuviPool(error))
    }

    static func removeCachedSensor(
        matching ruuviTag: RuuviTagSensor,
        from ruuviTags: [AnyRuuviTagSensor]
    ) -> [AnyRuuviTagSensor] {
        ruuviTags.filter { cachedSensor in
            let matchesMac = cachedSensor.macId != nil && cachedSensor.macId?.any == ruuviTag.macId?.any
            let matchesLuid = cachedSensor.luid != nil && cachedSensor.luid?.any == ruuviTag.luid?.any
            return !(matchesMac || matchesLuid)
        }
    }
}

public final class RuuviTagPropertiesDaemonBTKit: RuuviDaemonWorker, RuuviTagPropertiesDaemon {
    private let ruuviPool: RuuviPool
    private let ruuviReactor: RuuviReactor
    private let foreground: any PropertiesForegrounding
    private let idPersistence: any PropertiesIDPersisting
    private let sensorReader: any PropertiesSensorReading

    public convenience init(
        ruuviPool: RuuviPool,
        ruuviReactor: RuuviReactor,
        foreground: BTForeground,
        idPersistence: RuuviLocalIDs,
        sqiltePersistence: RuuviPersistence
    ) {
        self.init(
            ruuviPool: ruuviPool,
            ruuviReactor: ruuviReactor,
            foreground: PropertiesForegroundAdapter(foreground: foreground),
            idPersistence: PropertiesIDPersistenceAdapter(ids: idPersistence),
            sensorReader: PropertiesSensorReaderAdapter(persistence: sqiltePersistence)
        )
    }

    init(
        ruuviPool: RuuviPool,
        ruuviReactor: RuuviReactor,
        foreground: any PropertiesForegrounding,
        idPersistence: any PropertiesIDPersisting,
        sensorReader: any PropertiesSensorReading
    ) {
        self.ruuviPool = ruuviPool
        self.ruuviReactor = ruuviReactor
        self.foreground = foreground
        self.idPersistence = idPersistence
        self.sensorReader = sensorReader
        super.init()
    }

    private var ruuviTagsToken: RuuviReactorToken?
    private var observeTokens = [DaemonObservationToken]()
    private var scanTokens = [DaemonObservationToken]()
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
        let updatedSensor = RuuviTagPropertiesDaemonCore.updatedSensor(
            current: pair.ruuviTag,
            observed: pair.device,
            persistedMac: idPersistence.mac(for: pair.device.uuid.luid)
        )
        guard let updatedSensor else { return }

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.ruuviPool.update(updatedSensor)
            } catch let error as RuuviPoolError {
                self.handlePoolFailure(error, ruuviTag: pair.ruuviTag)
            } catch {
                self.handlePoolFailure(.ruuviPersistence(.grdb(error)), ruuviTag: pair.ruuviTag)
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
                            if let sensor = try? await observer.sensorReader.readOne(macId.mac) {
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
                  RuuviTagPropertiesDaemonCore.shouldProcessRemoteScan(
                    ruuviTag: ruuviTag,
                    device: device,
                    processingUUIDs: sSelf.processingUUIDs
                  )
            else {
                return
            }
            sSelf.processingUUIDs.insert(tag.uuid)
            let ruuviSensor = RuuviTagPropertiesDaemonCore.makeRemoteSensor(
                from: ruuviTag,
                mac: mac,
                tag: tag,
                device: device
            )
            sSelf.idPersistence.set(mac: mac, for: device.uuid.luid)
            sSelf.idPersistence.set(luid: device.uuid.luid, for: mac)
            Task { [weak sSelf] in
                guard let self = sSelf else { return }
                defer {
                    self.processingUUIDs.remove(tag.uuid)
                }
                do {
                    _ = try await self.ruuviPool.update(ruuviSensor)
                } catch let error as RuuviPoolError {
                    self.handlePoolFailure(error, ruuviTag: ruuviSensor)
                } catch {
                    self.handlePoolFailure(.ruuviPersistence(.grdb(error)), ruuviTag: ruuviSensor)
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
        switch RuuviTagPropertiesDaemonCore.poolFailureAction(for: error) {
        case .removeCachedSensor:
            removeCachedSensor(matching: ruuviTag)
            restartObserving()
        case let .postError(daemonError):
            post(error: daemonError)
        }
    }

    private func removeCachedSensor(matching ruuviTag: RuuviTagSensor) {
        ruuviTags = RuuviTagPropertiesDaemonCore.removeCachedSensor(
            matching: ruuviTag,
            from: ruuviTags
        )
    }
}
