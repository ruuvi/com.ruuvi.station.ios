#if SWIFT_PACKAGE
    import RuuviDaemon
    import RuuviDaemonOperation
#endif
// swiftlint:disable file_length

import BTKit
import Foundation
import RuuviLocal
import RuuviNotification
import RuuviNotifier
import RuuviOntology
import RuuviPool
import RuuviReactor
import RuuviService
import RuuviStorage
import UIKit

public final class RuuviTagHeartbeatDaemonBTKit: RuuviDaemonWorker, RuuviTagHeartbeatDaemon {
    private let transport: RuuviHeartbeatTransport
    private let notificationCenter: NotificationCenter
    private let localNotificationsManager: RuuviNotificationLocal
    private let connectionPersistence: RuuviLocalConnections
    private let ruuviPool: RuuviPool
    private let ruuviStorage: RuuviStorage
    private let ruuviReactor: RuuviReactor
    private let alertService: RuuviServiceAlert
    private let alertHandler: RuuviNotifier
    private let settings: RuuviLocalSettings
    private let titles: RuuviTagHeartbeatDaemonTitles
    private let widgetCache: WidgetSensorCache
    // Observation state is confined to the main queue, including Bluetooth and reactor callbacks.
    private var observationID: UUID?
    private var connectionGenerations = [String: UUID]()
    private var scanGeneration = UUID()
    private var settingsGenerations = [String: UUID]()
    private let persistenceGate = AdvertisementPersistenceGate()

    private var ruuviTags = [AnyRuuviTagSensor]()
    private var sensorSettingsList = [SensorSettings]()
    private var ruuviTagsByLuid = [AnyLocalIdentifier: AnyRuuviTagSensor]()
    private var sensorSettingsByLuid = [AnyLocalIdentifier: SensorSettings]()
    private var observeTokens = [() -> Void]()
    private var connectTokens = [String: () -> Void]()
    private var disconnectTokens = [String: () -> Void]()
    private var connectionAddedToken: NSObjectProtocol?
    private var connectionRemovedToken: NSObjectProtocol?
    private var savedDate = [String: Date]()  // [luid: date]
    private var lastSavedSequenceNumbers = [String: Int]()  // [uuid: sequenceNumber]
    private var ruuviTagsToken: RuuviReactorToken?
    private var sensorSettingsTokens = [String: RuuviReactorToken]()
    private var cloudModeOnToken: NSObjectProtocol?
    private var daemonRestartToken: NSObjectProtocol?
    private var appStateToken: NSObjectProtocol?
    private var appDidEnterBackgroundToken: NSObjectProtocol?

    // swiftlint:disable:next function_body_length
    public init(
        background: BTBackground,
        localNotificationsManager: RuuviNotificationLocal,
        connectionPersistence: RuuviLocalConnections,
        ruuviPool: RuuviPool,
        ruuviStorage: RuuviStorage,
        ruuviReactor: RuuviReactor,
        alertService: RuuviServiceAlert,
        alertHandler: RuuviNotifier,
        settings: RuuviLocalSettings,
        titles: RuuviTagHeartbeatDaemonTitles,
        transport: RuuviHeartbeatTransport? = nil,
        widgetCache: WidgetSensorCache = WidgetSensorCache(),
        notificationCenter: NotificationCenter = .default
    ) {
        self.transport = transport ?? BTKitHeartbeatTransport(background: background)
        self.widgetCache = widgetCache
        self.notificationCenter = notificationCenter
        self.localNotificationsManager = localNotificationsManager
        self.connectionPersistence = connectionPersistence
        self.ruuviPool = ruuviPool
        self.ruuviStorage = ruuviStorage
        self.ruuviReactor = ruuviReactor
        self.alertService = alertService
        self.alertHandler = alertHandler
        self.settings = settings
        self.titles = titles
        super.init()
        connectionAddedToken =
            notificationCenter
            .addObserver(
                forName: .ConnectionPersistenceDidStartToKeepConnection,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let sSelf = self, sSelf.observationID != nil else { return }
                    if let userInfo = notification.userInfo,
                        let uuid = userInfo[CPDidStartToKeepConnectionKey.uuid] as? String
                    {
                        sSelf.connect(uuid: uuid)
                    }
                }
            )

        connectionRemovedToken =
            notificationCenter
            .addObserver(
                forName: .ConnectionPersistenceDidStopToKeepConnection,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let sSelf = self, sSelf.observationID != nil else { return }
                    if let userInfo = notification.userInfo,
                        let uuid = userInfo[CPDidStopToKeepConnectionKey.uuid] as? String
                    {
                        sSelf.disconnect(uuid: uuid)
                    }
                }
            )
        cloudModeOnToken =
            notificationCenter
            .addObserver(
                forName: .CloudModeDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self, sSelf.observationID != nil else { return }
                sSelf.handleRuuviTagsChange()
            }

        daemonRestartToken =
            notificationCenter
            .addObserver(
                forName: .RuuviTagHeartBeatDaemonShouldRestart,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self, sSelf.observationID != nil else { return }
                sSelf.handleRuuviTagsChange()
            }

        appStateToken =
            notificationCenter
            .addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self, sSelf.observationID != nil else { return }
                sSelf.restartObserving()
            }

        // Also observe when app enters background
        appDidEnterBackgroundToken =
            notificationCenter
            .addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self, sSelf.observationID != nil else { return }
                sSelf.restartObserving()
            }
    }

    deinit {
        invalidateTokens()
        if let connectionAddedToken {
            notificationCenter.removeObserver(connectionAddedToken)
        }
        if let connectionRemovedToken {
            notificationCenter.removeObserver(connectionRemovedToken)
        }
        if let cloudModeOnToken {
            notificationCenter.removeObserver(cloudModeOnToken)
        }
        if let daemonRestartToken {
            notificationCenter.removeObserver(daemonRestartToken)
        }
        if let appStateToken {
            notificationCenter.removeObserver(appStateToken)
        }
        if let appDidEnterBackgroundToken {
            notificationCenter.removeObserver(appDidEnterBackgroundToken)
        }
    }

    public func start() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.observationID == nil else { return }
            let session = UUID()
            self.observationID = session
            self.start {}
            self.ruuviTagsToken = self.ruuviReactor.observe { [weak self] change in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.observationID == session else { return }
                    switch change {
                    case let .initial(sensors): self.ruuviTags = sensors
                    case let .update(sensor):
                        self.persistenceGate.invalidate(sensorID: sensor.id)
                        if let index = self.ruuviTags.firstIndex(of: sensor) { self.ruuviTags[index] = sensor }
                    case let .insert(sensor): self.ruuviTags.append(sensor)
                    case let .delete(sensor): self.ruuviTags.removeAll { $0.id == sensor.id }
                    case let .error(error):
                        self.post(error: .ruuviReactor(error))
                        return
                    }
                    self.handleRuuviTagsChange()
                }
            }
        }
    }

    public func stop() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.observationID != nil else { return }
            self.observationID = nil
            self.persistenceGate.syncSensors([])
            self.invalidateTokens()
            for luid in self.connectionPersistence.keepConnectionUUIDs { self.disconnect(uuid: luid.value) }
            self.stopWork()
        }
    }

    public func restart() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let session = self.observationID else { return }
            Task { @MainActor [self] in
                guard let sensors = try? await self.ruuviStorage.readAll(), self.observationID == session else { return }
                for sensor in sensors { self.persistenceGate.invalidate(sensorID: sensor.id) }
                self.ruuviTags = sensors
                self.handleRuuviTagsChange()
            }
        }
    }

}

// MARK: - Handlers

extension RuuviTagHeartbeatDaemonBTKit {
    private func connectedHandler(for uuid: String) -> ((RuuviTagHeartbeatDaemonBTKit, BTConnectResult) -> Void)? {
        { observer, result in
            switch result {
            case .already:
                break  // already connected, do nothing
            case .just:
                if observer.alertService.isOn(type: .connection, for: uuid) {
                    observer.notifyDidConnect(uuid: uuid)
                }
            case let .failure(error):
                observer.post(error: .btkit(error))
            case .disconnected:
                if observer.alertService.isOn(type: .connection, for: uuid) {
                    observer.notifyDidDisconnect(uuid: uuid)
                }
            }
        }
    }

    private func disconnectedHandler(
        for uuid: String
    ) -> ((RuuviTagHeartbeatDaemonBTKit, BTDisconnectResult) -> Void)? {
        { observer, result in
            switch result {
            case .stillConnected:
                break  // do nothing
            case .already:
                break  // do nothing
            case .bluetoothWasPoweredOff:
                if observer.alertService.isOn(type: .connection, for: uuid) {
                    observer.notifyDidDisconnect(uuid: uuid)
                }
            case .just:
                if observer.alertService.isOn(type: .connection, for: uuid) {
                    observer.notifyDidDisconnect(uuid: uuid)
                }
            case let .failure(error):
                observer.post(error: .btkit(error))
            }
        }
    }

    // Processes a RuuviTag for alerts and record creation based on settings.
    // swiftlint:disable:next function_body_length
    private func processRuuviTag(_ ruuviTag: RuuviTag, source: RuuviTagSensorRecordSource) {
        let ruuviTagSensor: AnyRuuviTagSensor? = {
            if let ruuviTagLuid = ruuviTag.luid?.any {
                if let match = ruuviTagsByLuid[ruuviTagLuid] {
                    return match
                }
                if let match = ruuviTags.first(where: { $0.luid?.any == ruuviTagLuid }) {
                    return match
                }
            }
            if let ruuviTagMac = ruuviTag.macId?.any {
                return ruuviTags.first(where: { $0.macId?.any == ruuviTagMac })
            }
            return nil
        }()
        let sensorSettings = sensorSettings(for: ruuviTagSensor)
        if let ruuviTagSensor {
            widgetCache.upsert(
                sensor: ruuviTagSensor,
                record: snapshot(from: ruuviTag, source: source),
                settings: sensorSettings
            )
        }
        let record = ruuviTag.with(sensorSettings: sensorSettings).with(source: source)
        #if DEBUG || ALPHA
            logAlertHeartbeatIfNeeded(
                record: record,
                ruuviTag: ruuviTag,
                ruuviTagSensor: ruuviTagSensor,
                source: source
            )
        #endif
        alertHandler.process(
            record: record,
            trigger: true
        )
        if settings.saveHeartbeats {
            let uuid = ruuviTag.uuid
            guard !uuid.isEmpty, ruuviTag.luid != nil else { return }
            let interval =
                settings.appIsOnForeground
                ? settings.saveHeartbeatsForegroundIntervalSeconds : settings.saveHeartbeatsIntervalMinutes * 60
            if let previous = savedDate[uuid], Date().timeIntervalSince(previous) <= TimeInterval(interval) {
                return
            }
            createRecords(ruuviTag: ruuviTag, uuid: uuid, source: source)
        }
    }

    #if DEBUG || ALPHA
        private func logAlertHeartbeatIfNeeded(
            record: PhysicalSensor,
            ruuviTag: RuuviTag,
            ruuviTagSensor: AnyRuuviTagSensor?,
            source: RuuviTagSensorRecordSource
        ) {
            guard alertService.hasRegistrations(for: record) else { return }

            let matchedSensor: String
            if let sensor = ruuviTagSensor {
                let sensorLuid = sensor.luid?.value ?? "nil"
                let sensorMac = sensor.macId?.value ?? "nil"
                matchedSensor =
                    "sensorId=\(sensor.id) " + "sensorLuid=\(sensorLuid) " + "sensorMac=\(sensorMac) "
                    + "isClaimed=\(sensor.isClaimed) " + "isOwner=\(sensor.isOwner) " + "isCloud=\(sensor.isCloud)"
            } else {
                matchedSensor = "sensor=nil"
            }
            RuuviAlertDebugLog.append(
                "AlertHeartbeat",
                "ble process trigger=true source=\(source.rawValue) " + "tagUuid=\(ruuviTag.uuid) "
                    + "tagLuid=\(ruuviTag.luid?.value ?? "nil") " + "tagMac=\(ruuviTag.macId?.value ?? "nil") "
                    + matchedSensor
            )
        }
    #endif

    /// Creates records for a RuuviTag and updates the saved date.
    private func createRecords(
        ruuviTag: RuuviTag,
        uuid: String,
        source: RuuviTagSensorRecordSource
    ) {
        guard !uuid.isEmpty else { return }

        let tagExists: Bool = {
            if let ruuviTagLuid = ruuviTag.luid?.any {
                if ruuviTagsByLuid[ruuviTagLuid] != nil {
                    return true
                }
                if ruuviTags.contains(where: { $0.luid?.any == ruuviTagLuid }) {
                    return true
                }
            }
            if let ruuviTagMac = ruuviTag.mac {
                return ruuviTags.contains { $0.macId?.value == ruuviTagMac }
            }
            return false
        }()

        guard tagExists else {
            return
        }

        // Check for duplicate sequence number
        let measurementSequenceNumber = ruuviTag.measurementSequenceNumber

        // Skip if we already processed this sequence number (except version v6)
        if ruuviTag.version != 0x06, let sequenceNumber = measurementSequenceNumber {
            guard lastSavedSequenceNumbers[uuid] != sequenceNumber else { return }
            lastSavedSequenceNumbers[uuid] = sequenceNumber
        }

        createRecord(ruuviTag: ruuviTag, uuid: uuid, source: source)
        savedDate[uuid] = Date()
    }

    /// Each write validates the sensor session again after suspension.
    private func createRecord(
        ruuviTag: RuuviTag,
        uuid: String,
        source: RuuviTagSensorRecordSource
    ) {
        guard let session = observationID,
            let sensor = ruuviTags.first(where: { $0.luid?.value == uuid || $0.macId?.value == ruuviTag.mac }),
            let generation = persistenceGate.generation(for: sensor.id)
        else { return }
        let record = ruuviTag.with(source: source)
        Task { @MainActor [self] in
            guard observationID == session, persistenceGate.generation(for: sensor.id) == generation else { return }
            do throws(RuuviPoolError) {
                if ruuviTag.version != 0x06 {
                    _ = try await ruuviPool.create(record)
                }
                guard observationID == session, persistenceGate.generation(for: sensor.id) == generation else { return }
                _ = try await ruuviPool.createLast(record)
            } catch {
                guard observationID == session, persistenceGate.generation(for: sensor.id) == generation else { return }
                resetSampling(for: sensor)
                post(error: .ruuviPool(error))
            }
        }
    }

}

// MARK: - Private

extension RuuviTagHeartbeatDaemonBTKit {
    // Updates connections and observations based on changes in Ruuvi tags.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func handleRuuviTagsChange() {
        var luidIndex = [AnyLocalIdentifier: AnyRuuviTagSensor]()
        for tag in ruuviTags {
            if let luid = tag.luid?.any {
                luidIndex[luid] = tag
            }
        }
        ruuviTagsByLuid = luidIndex
        let ruuviTagLuidValues = Set(ruuviTags.compactMap { $0.luid?.value })
        var ruuviTagIdentifierValues = Set<String>()
        ruuviTagIdentifierValues.reserveCapacity(ruuviTags.count * 2)
        for tag in ruuviTags {
            ruuviTagIdentifierValues.insert(tag.id)
            if let luid = tag.luid?.value {
                ruuviTagIdentifierValues.insert(luid)
            }
            if let mac = tag.macId?.value {
                ruuviTagIdentifierValues.insert(mac)
            }
        }
        persistenceGate.syncSensors(Set(ruuviTags.map(\.id)))
        widgetCache.syncSensors(ruuviTags) { [weak self] sensor in
            self?.sensorSettings(for: sensor)
        }
        for luid in connectionPersistence.keepConnectionUUIDs {
            let luidValue = luid.value
            let isRuuviTagPresent = ruuviTagLuidValues.contains(luidValue)
            if isRuuviTagPresent && connectTokens[luidValue] == nil {
                connect(uuid: luid.value)
            } else if !isRuuviTagPresent && connectTokens[luidValue] != nil {
                disconnect(uuid: luid.value)
            }
        }
        savedDate = savedDate.filter { ruuviTagIdentifierValues.contains($0.key) }
        lastSavedSequenceNumbers = lastSavedSequenceNumbers.filter { ruuviTagIdentifierValues.contains($0.key) }
        sensorSettingsList.removeAll()
        sensorSettingsByLuid.removeAll()
        for sensor in ruuviTags {
            let generation = UUID()
            let session = observationID
            settingsGenerations[sensor.id] = generation
            Task { @MainActor [self] in
                guard let value = try? await ruuviStorage.readSensorSettings(sensor), observationID == session,
                    settingsGenerations[sensor.id] == generation,
                    ruuviTags.contains(where: { $0.id == sensor.id })
                else { return }
                updateSensorSettings(sensor, value)
            }
        }
        restartSensorSettingsObservers()
        restartObserving()
    }

    private func sensorSettings(
        for ruuviTagSensor: AnyRuuviTagSensor?
    ) -> SensorSettings? {
        guard let ruuviTagSensor else { return nil }
        if let sensorLuid = ruuviTagSensor.luid?.any {
            if let settings = sensorSettingsByLuid[sensorLuid] {
                return settings
            }
            if let settings = sensorSettingsList.first(where: { $0.luid?.any == sensorLuid }) {
                return settings
            }
            if let sensorMac = ruuviTagSensor.macId?.any {
                return sensorSettingsList.first(where: { $0.macId?.any == sensorMac })
            }
            return nil
        }
        if let sensorMac = ruuviTagSensor.macId?.any {
            return sensorSettingsList.first(where: { $0.macId?.any == sensorMac })
        }
        return nil
    }

    private func snapshot(
        from ruuviTag: RuuviTag,
        source: RuuviTagSensorRecordSource
    ) -> WidgetSensorRecordSnapshot {
        let humidityFraction: Double? = {
            if let relative = ruuviTag.relativeHumidity {
                return relative / 100.0
            }
            return nil
        }()
        return WidgetSensorRecordSnapshot(
            date: Date(),
            source: source.rawValue,
            macId: ruuviTag.macId?.value,
            luid: ruuviTag.luid?.value,
            rssi: nil,
            version: ruuviTag.version,
            temperature: ruuviTag.celsius,
            humidity: humidityFraction,
            pressure: ruuviTag.hectopascals,
            accelerationX: ruuviTag.accelerationX,
            accelerationY: ruuviTag.accelerationY,
            accelerationZ: ruuviTag.accelerationZ,
            voltage: ruuviTag.volts,
            movementCounter: ruuviTag.movementCounter,
            measurementSequenceNumber: ruuviTag.measurementSequenceNumber,
            txPower: ruuviTag.txPower,
            pm1: ruuviTag.pMatter1,
            pm25: ruuviTag.pMatter25,
            pm4: ruuviTag.pMatter4,
            pm10: ruuviTag.pMatter10,
            co2: ruuviTag.carbonDioxide,
            voc: ruuviTag.volatileOrganicCompound,
            nox: ruuviTag.nitrogenOxide,
            luminance: ruuviTag.luminanceValue,
            dbaInstant: ruuviTag.decibelInstant,
            dbaAvg: ruuviTag.decibelAverage,
            dbaPeak: ruuviTag.decibelPeak,
            temperatureOffset: 0.0,
            humidityOffset: 0.0,
            pressureOffset: 0.0
        )
    }

    private func connect(uuid: String) {
        guard let session = observationID, connectTokens[uuid] == nil else { return }
        disconnectTokens.removeValue(forKey: uuid)?()
        let generation = UUID()
        connectionGenerations[uuid] = generation
        connectTokens[uuid] = transport.connect(
            uuid: uuid,
            connected: { [weak self] result in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.observationID == session, self.connectionGenerations[uuid] == generation else {
                        return
                    }
                    self.connectedHandler(for: uuid)?(self, result)
                }
            },
            heartbeat: { [weak self] tag in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.observationID == session, self.connectionGenerations[uuid] == generation else {
                        return
                    }
                    self.processRuuviTag(tag, source: .heartbeat)
                }
            },
            disconnected: { [weak self] result in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.observationID == session, self.connectionGenerations[uuid] == generation else {
                        return
                    }
                    self.disconnectedHandler(for: uuid)?(self, result)
                }
            })
    }

    private func disconnect(uuid: String) {
        let session = observationID
        connectionGenerations.removeValue(forKey: uuid)
        connectTokens.removeValue(forKey: uuid)?()
        disconnectTokens.removeValue(forKey: uuid)?()
        disconnectTokens[uuid] = transport.disconnect(uuid: uuid) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self, let session, self.observationID == session else { return }
                self.disconnectedHandler(for: uuid)?(self, result)
            }
        }
    }

    /// Invalidates all observation tokens to free resources.
    private func invalidateTokens() {
        autoreleasepool {
            ruuviTagsToken?.invalidate()
            ruuviTagsToken = nil
            connectionGenerations.removeAll()
            scanGeneration = UUID()
            settingsGenerations.removeAll()
            observeTokens.forEach { $0() }
            observeTokens.removeAll()
            connectTokens.values.forEach { $0() }
            connectTokens.removeAll()
            disconnectTokens.values.forEach { $0() }
            disconnectTokens.removeAll()
            sensorSettingsTokens.values.forEach { $0.invalidate() }
            sensorSettingsTokens.removeAll()
        }
    }

    private func post(error: RuuviDaemonError) {
        DispatchQueue.main.async { [notificationCenter] in
            notificationCenter.post(
                name: .RuuviTagHeartbeatDaemonDidFail,
                object: nil,
                userInfo: [RuuviTagHeartbeatDaemonDidFailKey.error: error]
            )
        }
    }

    private func notifyDidDisconnect(uuid: String) {
        let session = observationID
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self, session != nil, sSelf.observationID == session else { return }
            sSelf.localNotificationsManager.showDidDisconnect(
                uuid: uuid,
                title: sSelf.titles.didDisconnect
            )
        }
    }

    private func notifyDidConnect(uuid: String) {
        let session = observationID
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self, session != nil, sSelf.observationID == session else { return }
            sSelf.localNotificationsManager.showDidConnect(
                uuid: uuid,
                title: sSelf.titles.didConnect
            )
        }
    }
}

// MARK: - Sensor Settings

extension RuuviTagHeartbeatDaemonBTKit {
    private func restartObserving() {
        scanGeneration = UUID()
        let generation = scanGeneration
        observeTokens.forEach { $0() }
        observeTokens.removeAll()
        guard let session = observationID, !settings.appIsOnForeground, settings.saveHeartbeats else { return }
        for sensor in ruuviTags {
            guard !(settings.cloudModeEnabled && sensor.isCloud), let serviceUUID = sensor.serviceUUID,
                let luid = sensor.luid, !transport.isConnected(uuid: luid.value)
            else { continue }
            observeTokens.append(
                transport.observe(serviceUUID: serviceUUID) { [weak self] tag in
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.observationID == session, self.scanGeneration == generation,
                            tag.vC5?.serviceUUID != nil || tag.vE1_V6?.serviceUUID != nil,
                            !tag.isConnected, !self.settings.appIsOnForeground
                        else { return }
                        self.processRuuviTag(tag, source: .bgAdvertisement)
                    }
                })
        }
    }

    private func restartSensorSettingsObservers() {
        sensorSettingsTokens.values.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()
        guard let session = observationID else { return }
        for sensor in ruuviTags {
            sensorSettingsTokens[sensor.id] = ruuviReactor.observe(sensor) { [weak self] change in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.observationID == session,
                        self.ruuviTags.contains(where: { $0.id == sensor.id })
                    else { return }
                    self.settingsGenerations[sensor.id] = UUID()
                    switch change {
                    case let .initial(values): values.forEach { self.updateSensorSettings(sensor, $0) }
                    case let .insert(value), let .update(value): self.updateSensorSettings(sensor, value)
                    case let .delete(value):
                        self.widgetCache.removeSettings(for: sensor.id)
                        self.sensorSettingsList.removeAll { $0.id == value.id }
                        if let luid = value.luid?.any { self.sensorSettingsByLuid.removeValue(forKey: luid) }
                        self.resetSampling(for: sensor)
                    case let .error(error): self.post(error: .ruuviReactor(error))
                    }
                }
            }
        }
    }

    private func updateSensorSettings(_ sensor: AnyRuuviTagSensor, _ value: SensorSettings) {
        sensorSettingsList.removeAll { $0.id == value.id }
        sensorSettingsList.append(value)
        if let luid = value.luid?.any { sensorSettingsByLuid[luid] = value }
        resetSampling(for: sensor)
    }

    private func resetSampling(for sensor: AnyRuuviTagSensor) {
        persistenceGate.invalidate(sensorID: sensor.id)
        if let luid = sensor.luid?.value {
            savedDate.removeValue(forKey: luid)
            lastSavedSequenceNumbers.removeValue(forKey: luid)
        }
    }
}
// swiftlint:enable file_length
