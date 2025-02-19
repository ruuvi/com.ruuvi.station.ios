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

// swiftlint:disable file_length
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
    private var ruuviTagsToken: RuuviReactorToken?
    private var sensorSettingsTokens = [String: RuuviReactorToken]()
    private var cloudModeOnToken: NSObjectProtocol?
    private var daemonRestartToken: NSObjectProtocol?
    private let heartbeatQueue = DispatchQueue(label: "RuuviTagHeartbeatDaemonBTKit.heartbeatQueue")

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
                    guard let sSelf = self else { return }
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
        { observer, device in
            if let ruuviTag = device.ruuvi?.tag {
                var sensorSettings: SensorSettings?
                if let ruuviTagSensor = observer.ruuviTags
                    .first(where: {
                        ($0.macId?.value != nil && $0.macId?.value == ruuviTag.mac)
                            || ($0.luid?.any != nil && $0.luid?.any == ruuviTag.luid?.any)
                    }),
                    let settings = observer.sensorSettingsList
                        .first(where: {
                            ($0.luid?.any != nil && $0.luid?.any == ruuviTagSensor.luid?.any)
                                || ($0.macId?.any != nil && $0.macId?.any == ruuviTagSensor.macId?.any)
                        }) {
                    sensorSettings = settings
                }
                observer.alertHandler.process(
                    record: ruuviTag
                        .with(sensorSettings: sensorSettings)
                        .with(source: .heartbeat),
                    trigger: true
                )
                if observer.settings.saveHeartbeats {
                    let uuid = ruuviTag.uuid
                    // If the app is on foreground store all heartbeats
                    // Otherwise respect the settings
                    guard ruuviTag.luid != nil else { return }
                    let interval = observer.settings.appIsOnForeground ?
                        (observer.settings.saveHeartbeatsForegroundIntervalSeconds) :
                        (observer.settings.saveHeartbeatsIntervalMinutes * 60)
                    if let date = observer.savedDate[uuid] {
                        if Date().timeIntervalSince(date) > TimeInterval(interval) {
                            self.createRecords(
                                observer: observer,
                                ruuviTag: ruuviTag,
                                uuid: uuid,
                                source: .heartbeat
                            )
                        }
                    } else {
                        self.createRecords(
                            observer: observer,
                            ruuviTag: ruuviTag,
                            uuid: uuid,
                            source: .heartbeat
                        )
                    }
                }
            }
        }
    }

    private func disconnectedHandler(for uuid: String) ->
        ((RuuviTagHeartbeatDaemonBTKit, BTDisconnectResult) -> Void)? { { observer, result in
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

    private func createRecords(
        observer: RuuviTagHeartbeatDaemonBTKit,
        ruuviTag: RuuviTag,
        uuid: String,
        source: RuuviTagSensorRecordSource
    ) {
        createRecord(observer: observer, ruuviTag: ruuviTag, uuid: uuid, source: source)
        heartbeatQueue.async { [weak observer] in
            observer?.savedDate[uuid] = Date()
        }
    }

    private func createRecord(
        observer: RuuviTagHeartbeatDaemonBTKit,
        ruuviTag: RuuviTag,
        uuid: String,
        source: RuuviTagSensorRecordSource
    ) {
        observer.ruuviPool.create(
            ruuviTag
                .with(source: source)
        ).on(
            success: { [weak self] _ in
                self?.createLastRecord(
                    observer: observer,
                    ruuviTag: ruuviTag,
                    uuid: uuid,
                    source: source
                )
        })
    }

    private func createLastRecord(
        observer: RuuviTagHeartbeatDaemonBTKit,
        ruuviTag: RuuviTag,
        uuid: String,
        source: RuuviTagSensorRecordSource
    ) {
        if let tag = ruuviTags.first(where: { $0.luid?.value == uuid }) {
            ruuviStorage.readLatest(tag).on(success: { localRecord in
                let record = ruuviTag.with(source: source)
                if let localRecord,
                   record.macId?.value == localRecord.macId?.value {
                    observer.ruuviPool.updateLast(record)
                } else {
                    observer.ruuviPool.createLast(record)
                }
            })
        }
    }
}

// MARK: - Private

extension RuuviTagHeartbeatDaemonBTKit {
    private func handleRuuviTagsChange() {
        connectionPersistence.keepConnectionUUIDs
            .filter { luid -> Bool in
                ruuviTags.contains(where: { $0.luid?.any != nil
                        && $0.luid?.any == luid
                })
                    && !connectTokens.keys.contains(luid.value)
            }.forEach { connect(uuid: $0.value) }

        connectionPersistence.keepConnectionUUIDs
            .filter { luid -> Bool in
                !ruuviTags.contains(where: { $0.luid?.any != nil
                        && $0.luid?.any == luid
                })
                    && connectTokens.keys.contains(luid.value)
            }.forEach { disconnect(uuid: $0.value) }
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
        connectTokens[uuid] = background
            .connect(
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
        disconnectTokens[uuid] = background
            .disconnect(
                for: self,
                uuid: uuid,
                options: [.callbackQueue(.dispatch(heartbeatQueue))],
                result: disconnectedHandler(for: uuid)
            )
    }

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
            NotificationCenter
                .default
                .post(
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

    // swiftlint:disable:next function_body_length
    private func restartObserving() {
        observeTokens.forEach { $0.invalidate() }
        observeTokens.removeAll()

        for ruuviTag in ruuviTags {

            let shouldAvoidObserving =
                (settings.cloudModeEnabled && ruuviTag.isCloud) || settings.appIsOnForeground
            if shouldAvoidObserving {
                continue
            }
            guard let serviceUUID = ruuviTag.serviceUUID else { continue }
            observeTokens.append(
                background.observe(
                    self,
                    uuid: serviceUUID,
                    options: [.callbackQueue(.untouch)]
                ) {
                    [weak self] _, device in
                    guard let sSelf = self else { return }

                    if let ruuviTag = device.ruuvi?.tag,
                       ruuviTag.vC5?.serviceUUID != nil ||
                       ruuviTag.vE0_F0?.serviceUUID != nil,
                       ruuviTag.version != 0xF0 { // Do not store F0 data, we only store E0 among E0/F0
                        var sensorSettings: SensorSettings?
                        if let ruuviTagSensor = sSelf.ruuviTags
                            .first(where: {
                                ($0.macId?.value != nil && $0.macId?.value == ruuviTag.mac)
                                || ($0.luid?.any != nil && $0.luid?.any == ruuviTag.luid?.any)
                            }),
                           let settings = sSelf.sensorSettingsList
                            .first(where: {
                                ($0.luid?.any != nil && $0.luid?.any == ruuviTagSensor.luid?.any)
                                || ($0.macId?.any != nil && $0.macId?.any == ruuviTagSensor.macId?.any)
                            }) {
                            sensorSettings = settings
                        }
                        sSelf.alertHandler.process(
                            record: ruuviTag
                                .with(sensorSettings: sensorSettings)
                                .with(source: .bgAdvertisement),
                            trigger: true
                        )
                        if sSelf.settings.saveHeartbeats {
                            let uuid = ruuviTag.uuid
                            guard ruuviTag.luid != nil,
                                  ruuviTag.vC5?.serviceUUID != nil ||
                                  ruuviTag.vE0_F0?.serviceUUID != nil,
                                  ruuviTag.version != 0xF0 // Do not store F0 data, we only store E0 among E0/F0
                            else { return }
                            let interval = sSelf.settings.saveHeartbeatsForegroundIntervalSeconds
                            if let date = sSelf.savedDate[uuid] {
                                if Date().timeIntervalSince(date) > TimeInterval(interval) {
                                    sSelf.createRecords(
                                        observer: sSelf,
                                        ruuviTag: ruuviTag,
                                        uuid: uuid,
                                        source: .bgAdvertisement
                                    )
                                }
                            } else {
                                sSelf.createRecords(
                                    observer: sSelf,
                                    ruuviTag: ruuviTag,
                                    uuid: uuid,
                                    source: .bgAdvertisement
                                )
                            }
                        }
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
                            self.heartbeatQueue.async { [weak self] in
                                self?.savedDate.removeValue(forKey: luid)
                            }
                        }
                    case let .delete(deleteSensorSettings):
                        if let deleteIndex = self.sensorSettingsList.firstIndex(
                            where: { $0.id == deleteSensorSettings.id }
                        ) {
                            self.sensorSettingsList.remove(at: deleteIndex)
                        }
                    default:
                        break
                    }
                }
            )
        }
    }

    private func updateSensorSettings(
        _ ruuviTagSensor: AnyRuuviTagSensor,
        _ sensorSettings: SensorSettings
    ) {
        if let updateIndex = sensorSettingsList.firstIndex(
            where: { $0.id == sensorSettings.id }
        ) {
            sensorSettingsList[updateIndex] = sensorSettings
        } else {
            sensorSettingsList.append(sensorSettings)
        }
        if let luid = ruuviTagSensor.luid?.value {
            heartbeatQueue.async { [weak self] in
                self?.savedDate.removeValue(forKey: luid)
            }
        }
    }
}
