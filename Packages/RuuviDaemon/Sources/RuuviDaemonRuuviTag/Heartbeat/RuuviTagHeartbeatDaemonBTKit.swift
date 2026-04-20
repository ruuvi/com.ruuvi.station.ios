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

enum RuuviTagHeartbeatNotificationAction: Equatable {
    case none
    case notifyDidConnect
    case notifyDidDisconnect
    case postError(BTError)

    static func ==(lhs: RuuviTagHeartbeatNotificationAction, rhs: RuuviTagHeartbeatNotificationAction) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none), (.notifyDidConnect, .notifyDidConnect), (.notifyDidDisconnect, .notifyDidDisconnect):
            return true
        case (.postError, .postError):
            return true
        default:
            return false
        }
    }
}

enum RuuviTagHeartbeatPersistencePlan: Equatable {
    case skip
    case create(updateSequenceNumber: Int?)
}

struct RuuviTagHeartbeatDaemonCore {
    static func notificationAction(
        for result: BTConnectResult,
        alertsEnabled: Bool
    ) -> RuuviTagHeartbeatNotificationAction {
        switch result {
        case .already:
            return .none
        case .just:
            return alertsEnabled ? .notifyDidConnect : .none
        case let .failure(error):
            return .postError(error)
        case .disconnected:
            return alertsEnabled ? .notifyDidDisconnect : .none
        }
    }

    static func notificationAction(
        for result: BTDisconnectResult,
        alertsEnabled: Bool
    ) -> RuuviTagHeartbeatNotificationAction {
        switch result {
        case .stillConnected, .already:
            return .none
        case .bluetoothWasPoweredOff, .just:
            return alertsEnabled ? .notifyDidDisconnect : .none
        case let .failure(error):
            return .postError(error)
        }
    }

    static func matchingSensor(
        for ruuviTag: RuuviTag,
        ruuviTagsByLuid: [AnyLocalIdentifier: AnyRuuviTagSensor],
        ruuviTags: [AnyRuuviTagSensor]
    ) -> AnyRuuviTagSensor? {
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
    }

    static func sensorSettings(
        for ruuviTagSensor: AnyRuuviTagSensor?,
        sensorSettingsByLuid: [AnyLocalIdentifier: SensorSettings],
        sensorSettingsList: [SensorSettings]
    ) -> SensorSettings? {
        guard let ruuviTagSensor else { return nil }
        if let sensorLuid = ruuviTagSensor.luid?.any {
            if let settings = sensorSettingsByLuid[sensorLuid] {
                return settings
            }
            if let settings = sensorSettingsList.first(where: { $0.luid?.any == sensorLuid }) {
                return settings
            }
        }
        if let sensorMac = ruuviTagSensor.macId?.any {
            return sensorSettingsList.first(where: { $0.macId?.any == sensorMac })
        }
        return nil
    }

    static func pruneState(
        savedDate: [String: Date],
        lastSavedSequenceNumbers: [String: Int],
        keeping identifierValues: Set<String>
    ) -> (
        savedDate: [String: Date],
        lastSavedSequenceNumbers: [String: Int]
    ) {
        (
            savedDate: savedDate.filter { identifierValues.contains($0.key) },
            lastSavedSequenceNumbers: lastSavedSequenceNumbers.filter { identifierValues.contains($0.key) }
        )
    }

    static func snapshot(
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

    static func persistencePlan(
        saveHeartbeats: Bool,
        appIsOnForeground: Bool,
        foregroundIntervalSeconds: Int,
        backgroundIntervalMinutes: Int,
        tagExists: Bool,
        uuid: String,
        hasLuid: Bool,
        version: Int,
        measurementSequenceNumber: Int?,
        lastSavedSequenceNumber: Int?,
        lastSavedDate: Date?,
        now: Date = Date()
    ) -> RuuviTagHeartbeatPersistencePlan {
        guard saveHeartbeats, tagExists, !uuid.isEmpty, hasLuid else {
            return .skip
        }
        let interval = appIsOnForeground ?
            TimeInterval(foregroundIntervalSeconds) :
            TimeInterval(backgroundIntervalMinutes * 60)
        if let lastSavedDate, now.timeIntervalSince(lastSavedDate) <= interval {
            return .skip
        }
        if version != 0x06,
           let sequenceNumber = measurementSequenceNumber,
           lastSavedSequenceNumber == sequenceNumber {
            return .skip
        }
        if version != 0x06 {
            return .create(updateSequenceNumber: measurementSequenceNumber)
        }
        return .create(updateSequenceNumber: nil)
    }

    static func shouldObserveInBackground(
        ruuviTag: AnyRuuviTagSensor,
        appIsOnForeground: Bool,
        saveHeartbeats: Bool,
        cloudModeEnabled: Bool,
        isConnected: Bool
    ) -> Bool {
        guard !appIsOnForeground, saveHeartbeats else {
            return false
        }
        guard !(cloudModeEnabled && ruuviTag.isCloud) else {
            return false
        }
        return ruuviTag.serviceUUID != nil && ruuviTag.luid != nil && !isConnected
    }
}

protocol HeartbeatBackgrounding {
    func isConnected(uuid: String) -> Bool

    @discardableResult
    func connect<T: AnyObject>(
        for observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        connected: ((T, BTConnectResult) -> Void)?,
        heartbeat: ((T, BTDevice) -> Void)?,
        disconnected: ((T, BTDisconnectResult) -> Void)?
    ) -> DaemonObservationToken?

    @discardableResult
    func disconnect<T: AnyObject>(
        for observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        result: ((T, BTDisconnectResult) -> Void)?
    ) -> DaemonObservationToken?

    @discardableResult
    func observe<T: AnyObject>(
        _ observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        closure: @escaping (T, BTDevice) -> Void
    ) -> DaemonObservationToken
}

private struct HeartbeatBackgroundAdapter: HeartbeatBackgrounding {
    let background: BTBackground

    func isConnected(uuid: String) -> Bool {
        background.isConnected(uuid: uuid)
    }

    func connect<T: AnyObject>(
        for observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        connected: ((T, BTConnectResult) -> Void)?,
        heartbeat: ((T, BTDevice) -> Void)?,
        disconnected: ((T, BTDisconnectResult) -> Void)?
    ) -> DaemonObservationToken? {
        background.connect(
            for: observer,
            uuid: uuid,
            options: options,
            connected: connected,
            heartbeat: heartbeat,
            disconnected: disconnected
        ).map { token in
            DaemonObservationToken {
                token.invalidate()
            }
        }
    }

    func disconnect<T: AnyObject>(
        for observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        result: ((T, BTDisconnectResult) -> Void)?
    ) -> DaemonObservationToken? {
        background.disconnect(
            for: observer,
            uuid: uuid,
            options: options,
            result: result
        ).map { token in
            DaemonObservationToken {
                token.invalidate()
            }
        }
    }

    func observe<T: AnyObject>(
        _ observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        closure: @escaping (T, BTDevice) -> Void
    ) -> DaemonObservationToken {
        let token = background.observe(observer, uuid: uuid, options: options, closure: closure)
        return DaemonObservationToken {
            token.invalidate()
        }
    }
}

protocol HeartbeatLocalNotificationsHandling {
    func showDidConnect(uuid: String, title: String)
    func showDidDisconnect(uuid: String, title: String)
}

struct HeartbeatLocalNotificationsAdapter: HeartbeatLocalNotificationsHandling {
    let notifications: RuuviNotificationLocal

    func showDidConnect(uuid: String, title: String) {
        notifications.showDidConnect(uuid: uuid, title: title)
    }

    func showDidDisconnect(uuid: String, title: String) {
        notifications.showDidDisconnect(uuid: uuid, title: title)
    }
}

protocol HeartbeatConnectionsPersisting {
    var keepConnectionUUIDs: [AnyLocalIdentifier] { get }
}

struct HeartbeatConnectionsAdapter: HeartbeatConnectionsPersisting {
    let connections: RuuviLocalConnections

    var keepConnectionUUIDs: [AnyLocalIdentifier] {
        connections.keepConnectionUUIDs
    }
}

protocol HeartbeatAlertChecking {
    func isOn(type: AlertType, for uuid: String) -> Bool
}

private struct HeartbeatAlertServiceAdapter: HeartbeatAlertChecking {
    let alertService: RuuviServiceAlert

    func isOn(type: AlertType, for uuid: String) -> Bool {
        alertService.isOn(type: type, for: uuid)
    }
}

protocol HeartbeatNotifierHandling {
    func process(record ruuviTag: RuuviTagSensorRecord, trigger: Bool)
}

struct HeartbeatNotifierAdapter: HeartbeatNotifierHandling {
    let notifier: RuuviNotifier

    func process(record ruuviTag: RuuviTagSensorRecord, trigger: Bool) {
        notifier.process(record: ruuviTag, trigger: trigger)
    }
}

public final class RuuviTagHeartbeatDaemonBTKit: RuuviDaemonWorker, RuuviTagHeartbeatDaemon {
    private let background: any HeartbeatBackgrounding
    private let localNotificationsManager: any HeartbeatLocalNotificationsHandling
    private let connectionPersistence: any HeartbeatConnectionsPersisting
    private let ruuviPool: RuuviPool
    private let ruuviStorage: RuuviStorage
    private let ruuviReactor: RuuviReactor
    private let alertService: any HeartbeatAlertChecking
    private let alertHandler: any HeartbeatNotifierHandling
    private let settings: RuuviLocalSettings
    private let titles: RuuviTagHeartbeatDaemonTitles
    private let widgetCache = WidgetSensorCache()

    private var ruuviTags = [AnyRuuviTagSensor]()
    private var sensorSettingsList = [SensorSettings]()
    private var ruuviTagsByLuid = [AnyLocalIdentifier: AnyRuuviTagSensor]()
    private var sensorSettingsByLuid = [AnyLocalIdentifier: SensorSettings]()
    private var observeTokens = [DaemonObservationToken]()
    private var connectTokens = [String: DaemonObservationToken]()
    private var disconnectTokens = [String: DaemonObservationToken]()
    private var connectionAddedToken: NSObjectProtocol?
    private var connectionRemovedToken: NSObjectProtocol?
    private var savedDate = [String: Date]() // [luid: date]
    private var lastSavedSequenceNumbers = [String: Int]() // [uuid: sequenceNumber]
    private var ruuviTagsToken: RuuviReactorToken?
    private var sensorSettingsTokens = [String: RuuviReactorToken]()
    private var cloudModeOnToken: NSObjectProtocol?
    private var daemonRestartToken: NSObjectProtocol?
    private var appStateToken: NSObjectProtocol?
    private var appDidEnterBackgroundToken: NSObjectProtocol?

    private let heartbeatQueue = DispatchQueue(label: "RuuviTagHeartbeatDaemonBTKit.heartbeatQueue")
    private let stateQueue = DispatchQueue(label: "RuuviTagHeartbeatDaemonBTKit.stateQueue")

    // swiftlint:disable:next function_body_length
    public convenience init(
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
        self.init(
            background: HeartbeatBackgroundAdapter(background: background),
            localNotificationsManager: HeartbeatLocalNotificationsAdapter(
                notifications: localNotificationsManager
            ),
            connectionPersistence: HeartbeatConnectionsAdapter(
                connections: connectionPersistence
            ),
            ruuviPool: ruuviPool,
            ruuviStorage: ruuviStorage,
            ruuviReactor: ruuviReactor,
            alertService: HeartbeatAlertServiceAdapter(alertService: alertService),
            alertHandler: HeartbeatNotifierAdapter(notifier: alertHandler),
            settings: settings,
            titles: titles
        )
    }

    init(
        background: any HeartbeatBackgrounding,
        localNotificationsManager: any HeartbeatLocalNotificationsHandling,
        connectionPersistence: any HeartbeatConnectionsPersisting,
        ruuviPool: RuuviPool,
        ruuviStorage: RuuviStorage,
        ruuviReactor: RuuviReactor,
        alertService: any HeartbeatAlertChecking,
        alertHandler: any HeartbeatNotifierHandling,
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
        appDidEnterBackgroundToken = NotificationCenter.default
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
        if let appDidEnterBackgroundToken {
            NotificationCenter.default.removeObserver(appDidEnterBackgroundToken)
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
        Task { [weak self] in
            guard let self else { return }
            if let sensors = try? await self.ruuviStorage.readAll() {
                self.ruuviTags = sensors
                self.handleRuuviTagsChange()
                self.restartObserving()
            }
        }
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
            switch RuuviTagHeartbeatDaemonCore.notificationAction(
                for: result,
                alertsEnabled: observer.alertService.isOn(type: .connection, for: uuid)
            ) {
            case .none:
                break
            case .notifyDidConnect:
                observer.notifyDidConnect(uuid: uuid)
            case .notifyDidDisconnect:
                observer.notifyDidDisconnect(uuid: uuid)
            case let .postError(error):
                observer.post(error: .btkit(error))
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
        { observer, result in
            switch RuuviTagHeartbeatDaemonCore.notificationAction(
                for: result,
                alertsEnabled: observer.alertService.isOn(type: .connection, for: uuid)
            ) {
            case .none, .notifyDidConnect:
                break
            case .notifyDidDisconnect:
                observer.notifyDidDisconnect(uuid: uuid)
            case let .postError(error):
                observer.post(error: .btkit(error))
            }
        }
    }

    // Processes a RuuviTag for alerts and record creation based on settings.
    // swiftlint:disable:next function_body_length
    private func processRuuviTag(_ ruuviTag: RuuviTag, source: RuuviTagSensorRecordSource) {
        let ruuviTagSensor = RuuviTagHeartbeatDaemonCore.matchingSensor(
            for: ruuviTag,
            ruuviTagsByLuid: ruuviTagsByLuid,
            ruuviTags: ruuviTags
        )
        let sensorSettings = sensorSettings(for: ruuviTagSensor)
        if let ruuviTagSensor {
            widgetCache.upsert(
                sensor: ruuviTagSensor,
                record: snapshot(from: ruuviTag, source: source),
                settings: sensorSettings
            )
        }
        alertHandler.process(
            record: ruuviTag.with(sensorSettings: sensorSettings).with(source: source),
            trigger: true
        )
        if settings.saveHeartbeats {
            let uuid = ruuviTag.uuid
            guard !uuid.isEmpty, ruuviTag.luid != nil else { return }
            createRecords(
                observer: self,
                ruuviTag: ruuviTag,
                uuid: uuid,
                source: source
            )
        }
    }

    /// Creates records for a RuuviTag and updates the saved date.
    private func createRecords(
        observer: RuuviTagHeartbeatDaemonBTKit,
        ruuviTag: RuuviTag,
        uuid: String,
        source: RuuviTagSensorRecordSource
    ) {
        let tagExists = RuuviTagHeartbeatDaemonCore.matchingSensor(
            for: ruuviTag,
            ruuviTagsByLuid: ruuviTagsByLuid,
            ruuviTags: ruuviTags
        ) != nil
        let persistencePlan = stateQueue.sync {
            RuuviTagHeartbeatDaemonCore.persistencePlan(
                saveHeartbeats: settings.saveHeartbeats,
                appIsOnForeground: settings.appIsOnForeground,
                foregroundIntervalSeconds: settings.saveHeartbeatsForegroundIntervalSeconds,
                backgroundIntervalMinutes: settings.saveHeartbeatsIntervalMinutes,
                tagExists: tagExists,
                uuid: uuid,
                hasLuid: ruuviTag.luid != nil,
                version: ruuviTag.version,
                measurementSequenceNumber: ruuviTag.measurementSequenceNumber,
                lastSavedSequenceNumber: lastSavedSequenceNumbers[uuid],
                lastSavedDate: savedDate[uuid]
            )
        }
        guard case let .create(updateSequenceNumber) = persistencePlan else {
            return
        }
        stateQueue.sync {
            if let updateSequenceNumber {
                lastSavedSequenceNumbers[uuid] = updateSequenceNumber
            } else {
                lastSavedSequenceNumbers.removeValue(forKey: uuid)
            }
            savedDate[uuid] = Date()
        }
        createRecord(observer: observer, ruuviTag: ruuviTag, uuid: uuid, source: source)
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
            Task { [weak self] in
                if (try? await observer.ruuviPool.create(ruuviTag.with(source: source))) != nil {
                    self?.createLastRecord(observer: observer, ruuviTag: ruuviTag, uuid: uuid, source: source)
                }
            }
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
        Task {
            _ = try? await observer.ruuviPool.createLast(record)
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
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            let prunedState = RuuviTagHeartbeatDaemonCore.pruneState(
                savedDate: self.savedDate,
                lastSavedSequenceNumbers: self.lastSavedSequenceNumbers,
                keeping: ruuviTagIdentifierValues
            )
            self.savedDate = prunedState.savedDate
            self.lastSavedSequenceNumbers = prunedState.lastSavedSequenceNumbers
        }
        sensorSettingsList.removeAll()
        sensorSettingsByLuid.removeAll()
        Task { [weak self] in
            guard let self else { return }
            for ruuviTag in self.ruuviTags {
                do {
                    if let sensorSettings = try await self.ruuviStorage.readSensorSettings(ruuviTag) {
                        self.sensorSettingsList.append(sensorSettings)
                        if let luid = sensorSettings.luid?.any {
                            self.sensorSettingsByLuid[luid] = sensorSettings
                        }
                    }
                } catch {
                    continue
                }
            }
        }
        restartSensorSettingsObservers()
        restartObserving()
    }

    private func sensorSettings(
        for ruuviTagSensor: AnyRuuviTagSensor?
    ) -> SensorSettings? {
        RuuviTagHeartbeatDaemonCore.sensorSettings(
            for: ruuviTagSensor,
            sensorSettingsByLuid: sensorSettingsByLuid,
            sensorSettingsList: sensorSettingsList
        )
    }

    private func snapshot(
        from ruuviTag: RuuviTag,
        source: RuuviTagSensorRecordSource
    ) -> WidgetSensorRecordSnapshot {
        RuuviTagHeartbeatDaemonCore.snapshot(from: ruuviTag, source: source)
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

        for ruuviTag in ruuviTags {
            guard RuuviTagHeartbeatDaemonCore.shouldObserveInBackground(
                ruuviTag: ruuviTag,
                appIsOnForeground: settings.appIsOnForeground,
                saveHeartbeats: settings.saveHeartbeats,
                cloudModeEnabled: settings.cloudModeEnabled,
                isConnected: ruuviTag.luid.map { background.isConnected(uuid: $0.value) } ?? false
            ),
            let serviceUUID = ruuviTag.serviceUUID,
            ruuviTag.luid != nil else {
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
                        if let luid = sensorSettings.luid?.any {
                            self.sensorSettingsByLuid[luid] = sensorSettings
                        }
                        if let luid = ruuviTagSensor.luid?.value {
                            stateQueue.async { [weak self] in
                                self?.savedDate.removeValue(forKey: luid)
                                self?.lastSavedSequenceNumbers.removeValue(forKey: luid)
                            }
                        }
                    case let .delete(deleteSensorSettings):
                        if let deleteIndex = self.sensorSettingsList.firstIndex(where: {
                            $0.id == deleteSensorSettings.id
                        }) {
                            self.sensorSettingsList.remove(at: deleteIndex)
                        }
                        if let luid = deleteSensorSettings.luid?.any {
                            self.sensorSettingsByLuid.removeValue(forKey: luid)
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
        if let luid = sensorSettings.luid?.any {
            sensorSettingsByLuid[luid] = sensorSettings
        }
        if let luid = ruuviTagSensor.luid?.value {
            stateQueue.async { [weak self] in
                self?.savedDate.removeValue(forKey: luid)
                self?.lastSavedSequenceNumbers.removeValue(forKey: luid)
            }
        }
    }
}
// swiftlint:enable file_length
