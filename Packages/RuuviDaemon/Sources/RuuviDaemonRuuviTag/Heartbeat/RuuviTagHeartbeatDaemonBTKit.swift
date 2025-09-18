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
    private let background: BTBackground
    private let localNotificationsManager: RuuviNotificationLocal
    private let connectionPersistence: RuuviLocalConnections
    private let ruuviPool: RuuviPool
    private let ruuviStorage: RuuviStorage
    private let ruuviReactor: RuuviReactor
    private let alertService: RuuviServiceAlert
    private let alertHandler: RuuviNotifier
    private let settings: RuuviLocalSettings
    private let titles: RuuviTagHeartbeatDaemonTitles

    private var ruuviTags = [AnyRuuviTagSensor]()
    private var sensorSettingsList = [SensorSettings]()
    private var observeTokens = [ObservationToken]()
    private var connectTokens = [String: ObservationToken]()
    private var disconnectTokens = [String: ObservationToken]()
    private var connectionAddedToken: NSObjectProtocol?
    private var connectionRemovedToken: NSObjectProtocol?
    private var savedDate = [String: Date]() // [luid: date]
    private var lastSavedSequenceNumbers = [String: Int]() // [uuid: sequenceNumber]
    private var ruuviTagsToken: RuuviReactorToken?
    private var sensorSettingsTokens = [String: RuuviReactorToken]()
    private var cloudModeOnToken: NSObjectProtocol?
    private var daemonRestartToken: NSObjectProtocol?
    private var appStateToken: NSObjectProtocol?

    private let heartbeatQueue = DispatchQueue(label: "RuuviTagHeartbeatDaemonBTKit.heartbeatQueue")
    private let savedDateQueue = DispatchQueue(label: "RuuviTagHeartbeatDaemonBTKit.savedDateQueue")
    private let sequenceNumberQueue = DispatchQueue(label: "RuuviTagHeartbeatDaemonBTKit.sequenceNumberQueue")

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
        titles: RuuviTagHeartbeatDaemonTitles
    ) {
        self.background = background
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
        connectionAddedToken = NotificationCenter
            .default
            .addObserver(
                forName: .ConnectionPersistenceDidStartToKeepConnection,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let sSelf = self, sSelf.thread != nil else { return }
                    if let userInfo = notification.userInfo,
                       let uuid = userInfo[CPDidStartToKeepConnectionKey.uuid] as? String {
                        sSelf.perform(
                            #selector(RuuviTagHeartbeatDaemonBTKit.connect(uuid:)),
                            on: sSelf.thread,
                            with: uuid,
                            waitUntilDone: false,
                            modes: [RunLoop.Mode.default.rawValue]
                        )
                    }
                }
            )

        connectionRemovedToken = NotificationCenter
            .default
            .addObserver(
                forName: .ConnectionPersistenceDidStopToKeepConnection,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let sSelf = self else { return }
                    if let userInfo = notification.userInfo,
                       let uuid = userInfo[CPDidStopToKeepConnectionKey.uuid] as? String {
                        sSelf.perform(
                            #selector(RuuviTagHeartbeatDaemonBTKit.disconnect(uuid:)),
                            on: sSelf.thread,
                            with: uuid,
                            waitUntilDone: false,
                            modes: [RunLoop.Mode.default.rawValue]
                        )
                    }
                }
            )
        cloudModeOnToken = NotificationCenter
            .default
            .addObserver(
                forName: .CloudModeDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self else { return }
                sSelf.handleRuuviTagsChange()
            }

        daemonRestartToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagHeartBeatDaemonShouldRestart,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self else { return }
                sSelf.handleRuuviTagsChange()
            }

        appStateToken = NotificationCenter.default
            .addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self else { return }
                sSelf.restartObserving()
            }

        // Also observe when app enters background
        NotificationCenter.default
            .addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self else { return }
                sSelf.restartObserving()
            }
    }

    deinit {
        invalidateTokens()
        if let connectionAddedToken {
            NotificationCenter.default.removeObserver(connectionAddedToken)
        }
        if let connectionRemovedToken {
            NotificationCenter.default.removeObserver(connectionRemovedToken)
        }
        if let cloudModeOnToken {
            NotificationCenter.default.removeObserver(cloudModeOnToken)
        }
        if let daemonRestartToken {
            NotificationCenter.default.removeObserver(daemonRestartToken)
        }
        if let appStateToken {
            NotificationCenter.default.removeObserver(appStateToken)
        }
    }

    public func start() {
        start { [weak self] in
            self?.invalidateTokens()
            self?.ruuviTagsToken = self?.ruuviReactor.observe { [weak self] change in
                guard let sSelf = self else { return }
                switch change {
                case let .initial(ruuviTags):
                    sSelf.ruuviTags = ruuviTags
                    sSelf.handleRuuviTagsChange()
                case let .update(ruuviTag):
                    if let index = sSelf.ruuviTags.firstIndex(of: ruuviTag) {
                        sSelf.ruuviTags[index] = ruuviTag
                    }
                    sSelf.handleRuuviTagsChange()
                case let .insert(ruuviTag):
                    sSelf.ruuviTags.append(ruuviTag)
                    sSelf.handleRuuviTagsChange()
                case let .delete(ruuviTag):
                    sSelf.ruuviTags.removeAll(where: { $0.id == ruuviTag.id })
                    sSelf.handleRuuviTagsChange()
                case let .error(error):
                    sSelf.post(error: .ruuviReactor(error))
                }
            }
        }
    }

    public func stop() {
        perform(
            #selector(RuuviTagHeartbeatDaemonBTKit.stopDaemon),
            on: thread,
            with: nil,
            waitUntilDone: false,
            modes: [RunLoop.Mode.default.rawValue]
        )
    }

    public func restart() {
        ruuviStorage.readAll().on(success: { [weak self] sensors in
            self?.ruuviTags = sensors
            self?.handleRuuviTagsChange()
            self?.restartObserving()
        })
    }

    @objc private func stopDaemon() {
        invalidateTokens()
        connectionPersistence.keepConnectionUUIDs.forEach { disconnect(uuid: $0.value) }
        stopWork()
    }
}

// MARK: - Handlers

extension RuuviTagHeartbeatDaemonBTKit {
    private func connectedHandler(for uuid: String) -> ((RuuviTagHeartbeatDaemonBTKit, BTConnectResult) -> Void)? {
        { observer, result in
            switch result {
            case .already:
                break // already connected, do nothing
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

    private func heartbeatHandler() -> ((RuuviTagHeartbeatDaemonBTKit, BTDevice) -> Void)? {
        { [weak self] _, device in
            guard let sSelf = self else { return }
            if let ruuviTag = device.ruuvi?.tag {
                sSelf.processRuuviTag(ruuviTag, source: .heartbeat)
            }
        }
    }

    private func disconnectedHandler(
        for uuid: String
    ) -> ((RuuviTagHeartbeatDaemonBTKit, BTDisconnectResult) -> Void)? {
        { observer, result in // swiftlint:disable:this opening_brace
            switch result {
            case .stillConnected:
                break // do nothing
            case .already:
                break // do nothing
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

    /// Processes a RuuviTag for alerts and record creation based on settings.
    private func processRuuviTag(_ ruuviTag: RuuviTag, source: RuuviTagSensorRecordSource) {
        var sensorSettings: SensorSettings?
        if let ruuviTagSensor = ruuviTags.first(where: {
            macsMatchLoose($0.macId?.value, ruuviTag.mac) ||
            ($0.luid?.any != nil && $0.luid?.any == ruuviTag.luid?.any)
        }),
           let settings = sensorSettingsList.first(where: {
            ($0.luid?.any != nil && $0.luid?.any == ruuviTagSensor.luid?.any) ||
            ($0.macId?.any != nil && macsMatchLoose($0.macId?.value, ruuviTagSensor.macId?.value))
        }) {
            sensorSettings = settings
        }
        alertHandler.process(
            record: ruuviTag.with(sensorSettings: sensorSettings).with(source: source),
            trigger: true
        )
        if settings.saveHeartbeats {
            let uuid = ruuviTag.uuid
            guard !uuid.isEmpty, ruuviTag.luid != nil else { return }
            let interval = settings.appIsOnForeground ?
                settings.saveHeartbeatsForegroundIntervalSeconds :
                settings.saveHeartbeatsIntervalMinutes * 60
            savedDateQueue.async { [weak self] in
                guard let self = self else { return }
                if let date = self.savedDate[uuid] {
                    if Date().timeIntervalSince(date) > TimeInterval(interval) {
                        self.createRecords(
                            observer: self,
                            ruuviTag: ruuviTag,
                            uuid: uuid,
                            source: source
                        )
                    }
                } else {
                    self.createRecords(
                        observer: self,
                        ruuviTag: ruuviTag,
                        uuid: uuid,
                        source: source
                    )
                }
            }
        }
    }

    /// Creates records for a RuuviTag and updates the saved date.
    private func createRecords(
        observer: RuuviTagHeartbeatDaemonBTKit,
        ruuviTag: RuuviTag,
        uuid: String,
        source: RuuviTagSensorRecordSource
    ) {
        guard !uuid.isEmpty else { return }

        let tagExists = ruuviTags.contains { tagSensor in
            if let tagMacId = tagSensor.macId?.value,
               let ruuviTagMac = ruuviTag.mac,
               tagMacId == ruuviTagMac {
                return true
            }
            if let tagLuid = tagSensor.luid?.any,
               let ruuviTagLuid = ruuviTag.luid?.any,
               tagLuid == ruuviTagLuid {
                return true
            }
            return false
        }

        guard tagExists else {
            return
        }

        // Check for duplicate sequence number
        let measurementSequenceNumber = ruuviTag.measurementSequenceNumber

        // Skip if we already processed this sequence number (except version v6)
        if ruuviTag.version != 0x06, let sequenceNumber = measurementSequenceNumber {
            var shouldCreate = false
            sequenceNumberQueue.sync {
                if lastSavedSequenceNumbers[uuid] != sequenceNumber {
                    lastSavedSequenceNumbers[uuid] = sequenceNumber
                    shouldCreate = true
                }
            }

            if !shouldCreate {
                return
            }
        }

        createRecord(observer: observer, ruuviTag: ruuviTag, uuid: uuid, source: source)
        savedDateQueue.async {
            observer.savedDate[uuid] = Date()
        }
    }

    /// Creates a single record in the pool, handling potential errors.
    private func createRecord(
        observer: RuuviTagHeartbeatDaemonBTKit,
        ruuviTag: RuuviTag,
        uuid: String,
        source: RuuviTagSensorRecordSource
    ) {
        // Do not store advertisement for history only if it is v6 firmware and legacy advertisement.
        guard !uuid.isEmpty else { return }
        if ruuviTag.version == 0x06 {
            createLastRecord(observer: observer, ruuviTag: ruuviTag, uuid: uuid, source: source)
        } else {
            observer.ruuviPool.create(ruuviTag.with(source: source)).on(
                success: { [weak self] _ in
                    self?.createLastRecord(observer: observer, ruuviTag: ruuviTag, uuid: uuid, source: source)
                })
        }
    }

    /// Creates the last record for a RuuviTag.
    private func createLastRecord(
        observer: RuuviTagHeartbeatDaemonBTKit,
        ruuviTag: RuuviTag,
        uuid: String,
        source: RuuviTagSensorRecordSource
    ) {
        let record = ruuviTag.with(source: source)
        observer.ruuviPool.createLast(record)
    }
}

// MARK: - Private

extension RuuviTagHeartbeatDaemonBTKit {
    /// Updates connections and observations based on changes in Ruuvi tags.
    private func handleRuuviTagsChange() {
        for luid in connectionPersistence.keepConnectionUUIDs {
            let isRuuviTagPresent = ruuviTags.contains { $0.luid?.any == luid }
            if isRuuviTagPresent && !connectTokens.keys.contains(luid.value) {
                connect(uuid: luid.value)
            } else if !isRuuviTagPresent && connectTokens.keys.contains(luid.value) {
                disconnect(uuid: luid.value)
            }
        }
        sensorSettingsList.removeAll()
        ruuviTags.forEach { ruuviTag in
            ruuviStorage.readSensorSettings(ruuviTag).on { [weak self] sensorSettings in
                if let sensorSettings {
                    self?.sensorSettingsList.append(sensorSettings)
                }
            }
        }
        restartSensorSettingsObservers()
        restartObserving()
    }

    @objc private func connect(uuid: String) {
        disconnectTokens[uuid]?.invalidate()
        disconnectTokens.removeValue(forKey: uuid)
        connectTokens[uuid] = background.connect(
            for: self,
            uuid: uuid,
            options: [.callbackQueue(.dispatch(heartbeatQueue))],
            connected: connectedHandler(for: uuid),
            heartbeat: heartbeatHandler(),
            disconnected: disconnectedHandler(for: uuid)
        )
    }

    @objc private func disconnect(uuid: String) {
        connectTokens[uuid]?.invalidate()
        connectTokens.removeValue(forKey: uuid)
        sensorSettingsTokens[uuid]?.invalidate()
        sensorSettingsTokens.removeValue(forKey: uuid)
        disconnectTokens[uuid] = background.disconnect(
            for: self,
            uuid: uuid,
            options: [.callbackQueue(.dispatch(heartbeatQueue))],
            result: disconnectedHandler(for: uuid)
        )
    }

    /// Invalidates all observation tokens to free resources.
    private func invalidateTokens() {
        autoreleasepool {
            ruuviTagsToken?.invalidate()
            observeTokens.forEach { $0.invalidate() }
            observeTokens.removeAll()
            connectTokens.values.forEach { $0.invalidate() }
            connectTokens.removeAll()
            disconnectTokens.values.forEach { $0.invalidate() }
            disconnectTokens.removeAll()
            sensorSettingsTokens.values.forEach { $0.invalidate() }
            sensorSettingsTokens.removeAll()
        }
    }

    private func post(error: RuuviDaemonError) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .RuuviTagHeartbeatDaemonDidFail,
                object: nil,
                userInfo: [RuuviTagHeartbeatDaemonDidFailKey.error: error]
            )
        }
    }

    private func notifyDidDisconnect(uuid: String) {
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            sSelf.localNotificationsManager.showDidDisconnect(
                uuid: uuid,
                title: sSelf.titles.didDisconnect
            )
        }
    }

    private func notifyDidConnect(uuid: String) {
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
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
        observeTokens.forEach { $0.invalidate() }
        observeTokens.removeAll()

        if settings.appIsOnForeground {
            return
        }

        for ruuviTag in ruuviTags {
            let shouldAvoidObserving = (settings.cloudModeEnabled && ruuviTag.isCloud)
            if shouldAvoidObserving {
                continue
            }
            guard let serviceUUID = ruuviTag.serviceUUID,
                  let luid = ruuviTag.luid,
                  !background.isConnected(uuid: luid.value) else {
                continue
            }
            observeTokens.append(
                background.observe(
                    self,
                    uuid: serviceUUID,
                    options: [.callbackQueue(.untouch)]
                ) { [weak self] _, device in
                    guard let sSelf = self else { return }
                    if let ruuviTag = device.ruuvi?.tag,
                        ruuviTag.vC5?.serviceUUID != nil || ruuviTag.vE1_V6?.serviceUUID != nil,
                       !ruuviTag.isConnected, !sSelf.settings.appIsOnForeground {
                        sSelf.processRuuviTag(ruuviTag, source: .bgAdvertisement)
                    }
                }
            )
        }
    }

    private func restartSensorSettingsObservers() {
        sensorSettingsTokens.forEach { $0.value.invalidate() }
        sensorSettingsTokens.removeAll()

        ruuviTags.forEach { ruuviTagSensor in
            sensorSettingsTokens[ruuviTagSensor.id] = ruuviReactor.observe(
                ruuviTagSensor, { [weak self] change in
                    guard let self else { return }
                    switch change {
                    case let .initial(initialSensorSettings):
                        initialSensorSettings.forEach {
                            self.updateSensorSettings(ruuviTagSensor, $0)
                        }
                    case let .update(updateSensorSettings):
                        self.updateSensorSettings(ruuviTagSensor, updateSensorSettings)
                    case let .insert(sensorSettings):
                        self.sensorSettingsList.append(sensorSettings)
                        if let luid = ruuviTagSensor.luid?.value {
                            savedDateQueue.async { [weak self] in
                                self?.savedDate.removeValue(forKey: luid)
                            }
                        }
                    case let .delete(deleteSensorSettings):
                        if let deleteIndex = self.sensorSettingsList.firstIndex(where: {
                            $0.id == deleteSensorSettings.id
                        }) {
                            self.sensorSettingsList.remove(at: deleteIndex)
                        }
                    default:
                        break
                    }
                }
            )
        }
    }

    private func updateSensorSettings(_ ruuviTagSensor: AnyRuuviTagSensor, _ sensorSettings: SensorSettings) {
        if let updateIndex = sensorSettingsList.firstIndex(where: { $0.id == sensorSettings.id }) {
            sensorSettingsList[updateIndex] = sensorSettings
        } else {
            sensorSettingsList.append(sensorSettings)
        }
        if let luid = ruuviTagSensor.luid?.value {
            savedDateQueue.async { [weak self] in
                self?.savedDate.removeValue(forKey: luid)
            }
        }
    }

    private func normalizedMACComponents(_ mac: String?) -> [String]? {
        guard let mac = mac else { return nil }
        let comps = mac.split(separator: ":").map { $0.uppercased() }
        guard comps.count == 3 || comps.count == 6 else { return nil }
        return comps
    }

    /// Exact match OR last-3-bytes match (when one side is 3 bytes)
    private func macsMatchLoose(_ a: String?, _ b: String?) -> Bool {
        guard let ca = normalizedMACComponents(a),
              let cb = normalizedMACComponents(b) else { return false }

        if ca == cb { return true }
        if ca.count == 6, cb.count == 3 { return Array(ca.suffix(3)) == cb }
        if ca.count == 3, cb.count == 6 { return ca == Array(cb.suffix(3)) }
        return false
    }

    /// Prefer a full (6-byte) MAC if either side has it; otherwise return whichever is non-nil.
    private func preferFullMAC(_ a: String?, _ b: String?) -> String? {
        let ca = normalizedMACComponents(a)
        let cb = normalizedMACComponents(b)
        if let ca, ca.count == 6 { return ca.joined(separator: ":") }
        if let cb, cb.count == 6 { return cb.joined(separator: ":") }
        if let ca { return ca.joined(separator: ":") }
        if let cb { return cb.joined(separator: ":") }
        return nil
    }

    /// Is this a 6-byte MAC?
    private func isFullMAC(_ mac: String?) -> Bool {
        normalizedMACComponents(mac)?.count == 6
    }
}
// swiftlint:enable file_length
