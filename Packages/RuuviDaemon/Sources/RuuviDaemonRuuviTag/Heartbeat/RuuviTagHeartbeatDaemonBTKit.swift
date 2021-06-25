import Foundation
import BTKit
import RuuviOntology
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviPool
import RuuviService
import RuuviNotification
import RuuviNotifier

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
    private let pullWebDaemon: PullWebDaemon
    private let titles: RuuviTagHeartbeatDaemonTitles

    private var ruuviTags = [AnyRuuviTagSensor]()
    private var sensorSettingsList = [SensorSettings]()
    private var connectTokens = [String: ObservationToken]()
    private var disconnectTokens = [String: ObservationToken]()
    private var connectionAddedToken: NSObjectProtocol?
    private var connectionRemovedToken: NSObjectProtocol?
    private var savedDate = [String: Date]() // [luid: date]
    private var ruuviTagsToken: RuuviReactorToken?
    private var sensorSettingsTokens = [String: RuuviReactorToken]()

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
        pullWebDaemon: PullWebDaemon,
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
        self.pullWebDaemon = pullWebDaemon
        self.titles = titles
        super.init()
        connectionAddedToken = NotificationCenter
            .default
            .addObserver(forName: .ConnectionPersistenceDidStartToKeepConnection,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            guard let sSelf = self else { return }
                            if let userInfo = notification.userInfo,
                               let uuid = userInfo[CPDidStartToKeepConnectionKey.uuid] as? String {
                                sSelf.perform(#selector(RuuviTagHeartbeatDaemonBTKit.connect(uuid:)),
                                              on: sSelf.thread,
                                              with: uuid,
                                              waitUntilDone: false,
                                              modes: [RunLoop.Mode.default.rawValue])
                            }
                         })

        connectionRemovedToken = NotificationCenter
            .default
            .addObserver(forName: .ConnectionPersistenceDidStopToKeepConnection,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            guard let sSelf = self else { return }
                            if let userInfo = notification.userInfo,
                               let uuid = userInfo[CPDidStopToKeepConnectionKey.uuid] as? String {
                                sSelf.perform(#selector(RuuviTagHeartbeatDaemonBTKit.disconnect(uuid:)),
                                              on: sSelf.thread,
                                              with: uuid,
                                              waitUntilDone: false,
                                              modes: [RunLoop.Mode.default.rawValue])
                            }
                         })
    }

    deinit {
        invalidateTokens()
        connectionAddedToken?.invalidate()
        connectionRemovedToken?.invalidate()
    }

    public func start() {
        start { [weak self] in
            self?.invalidateTokens()
            self?.ruuviTagsToken = self?.ruuviReactor.observe({ [weak self] change in
                guard let sSelf = self else { return }
                switch change {
                case .initial(let ruuviTags):
                    sSelf.ruuviTags = ruuviTags
                    sSelf.handleRuuviTagsChange()
                case .update(let ruuviTag):
                    if let index = sSelf.ruuviTags.firstIndex(of: ruuviTag) {
                        sSelf.ruuviTags[index] = ruuviTag
                    }
                    sSelf.handleRuuviTagsChange()
                case .insert(let ruuviTag):
                    sSelf.ruuviTags.append(ruuviTag)
                    sSelf.handleRuuviTagsChange()
                case .delete(let ruuviTag):
                    sSelf.ruuviTags.removeAll(where: { $0.id == ruuviTag.id })
                    sSelf.handleRuuviTagsChange()
                case .error(let error):
                    sSelf.post(error: .ruuviReactor(error))
                }
            })

        }
    }

    public func stop() {
        perform(#selector(RuuviTagHeartbeatDaemonBTKit.stopDaemon),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
    }

    @objc private func stopDaemon() {
        invalidateTokens()
        connectionPersistence.keepConnectionUUIDs.forEach({ disconnect(uuid: $0.value) })
        stopWork()
    }
}

// MARK: - Handlers
extension RuuviTagHeartbeatDaemonBTKit {
    private func connectedHandler(for uuid: String) -> ((RuuviTagHeartbeatDaemonBTKit, BTConnectResult) -> Void)? {
        return { observer, result in
            switch result {
            case .already:
                break // already connected, do nothing
            case .just:
                if observer.alertService.isOn(type: .connection, for: uuid) {
                    observer.notifyDidConnect(uuid: uuid)
                }
            case .failure(let error):
                observer.post(error: .btkit(error))
            case .disconnected:
                if observer.alertService.isOn(type: .connection, for: uuid) {
                    observer.notifyDidDisconnect(uuid: uuid)
                }
            }
        }
    }

    private func heartbeatHandler() -> ((RuuviTagHeartbeatDaemonBTKit, BTDevice) -> Void)? {
        return { observer, device in
            observer.pullWebDaemon.wakeUp()
            if let ruuviTag = device.ruuvi?.tag {
                var sensorSettings: SensorSettings?
                if let ruuviTagSensor = observer.ruuviTags
                    .first(where: { $0.macId?.value == ruuviTag.mac || $0.luid?.any == ruuviTag.luid?.any }),
                   let settings = observer.sensorSettingsList
                    .first(where: {
                            ($0.luid?.any == ruuviTagSensor.luid?.any)
                                || ($0.macId?.any == ruuviTagSensor.macId?.any)
                    }) {
                    sensorSettings = settings
                }
                observer.alertHandler.process(
                    heartbeat: ruuviTag
                        .with(sensorSettings: sensorSettings)
                        .with(source: .heartbeat)
                )
                if observer.settings.saveHeartbeats {
                    let uuid = ruuviTag.uuid
                    let interval = observer.settings.saveHeartbeatsIntervalMinutes
                    if let date = observer.savedDate[uuid] {
                        if Date().timeIntervalSince(date) > TimeInterval(interval * 60) {
                            observer.ruuviPool.create(
                                ruuviTag
                                    .with(source: .heartbeat)
                                    .with(sensorSettings: sensorSettings)
                            )
                            observer.savedDate[uuid] = Date()
                        }
                    } else {
                        observer.ruuviPool.create(
                            ruuviTag
                                .with(source: .heartbeat)
                                .with(sensorSettings: sensorSettings)
                        )
                        observer.savedDate[uuid] = Date()
                    }
                }
            }
        }
    }

    private func disconnectedHandler(for uuid: String) ->
    ((RuuviTagHeartbeatDaemonBTKit, BTDisconnectResult) -> Void)? {
        return { observer, result in
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
            case .failure(let error):
                observer.post(error: .btkit(error))
            }
        }
    }
}

// MARK: - Private
extension RuuviTagHeartbeatDaemonBTKit {
    private func handleRuuviTagsChange() {
        connectionPersistence.keepConnectionUUIDs
            .filter { (luid) -> Bool in
                ruuviTags.contains(where: { $0.luid?.any == luid }) && !connectTokens.keys.contains(luid.value)
            }.forEach({ connect(uuid: $0.value) })

        connectionPersistence.keepConnectionUUIDs
            .filter { (luid) -> Bool in
                !ruuviTags.contains(where: { $0.luid?.any == luid }) && connectTokens.keys.contains(luid.value)
            }.forEach({ disconnect(uuid: $0.value) })
        sensorSettingsList.removeAll()
        ruuviTags.forEach { ruuviTag in
            ruuviStorage.readSensorSettings(ruuviTag).on {[weak self] sensorSettings in
                if let sensorSettings = sensorSettings {
                    self?.sensorSettingsList.append(sensorSettings)
                }
            }
        }
        restartSensorSettingsObservers()
    }

    @objc private func connect(uuid: String) {
        disconnectTokens[uuid]?.invalidate()
        disconnectTokens.removeValue(forKey: uuid)
        connectTokens[uuid] = background
            .connect(for: self,
                     uuid: uuid,
                     options: [.callbackQueue(.untouch)],
                     connected: connectedHandler(for: uuid),
                     heartbeat: heartbeatHandler(),
                     disconnected: disconnectedHandler(for: uuid))
    }

    @objc private func disconnect(uuid: String) {
        connectTokens[uuid]?.invalidate()
        connectTokens.removeValue(forKey: uuid)
        sensorSettingsTokens[uuid]?.invalidate()
        sensorSettingsTokens.removeValue(forKey: uuid)
        disconnectTokens[uuid] = background
            .disconnect(for: self,
                        uuid: uuid,
                        options: [.callbackQueue(.untouch)],
                        result: disconnectedHandler(for: uuid))
    }

    private func invalidateTokens() {
        autoreleasepool {
            ruuviTagsToken?.invalidate()
            connectTokens.values.forEach({ $0.invalidate() })
            connectTokens.removeAll()
            disconnectTokens.values.forEach({ $0.invalidate() })
            disconnectTokens.removeAll()
            sensorSettingsTokens.values.forEach({ $0.invalidate() })
            sensorSettingsTokens.removeAll()
        }
    }

    private func post(error: RuuviDaemonError) {
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(name: .RuuviTagHeartbeatDaemonDidFail,
                      object: nil,
                      userInfo: [RuuviTagHeartbeatDaemonDidFailKey.error: error])
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
    private func restartSensorSettingsObservers() {
        sensorSettingsTokens.forEach({ $0.value.invalidate() })
        sensorSettingsTokens.removeAll()

        ruuviTags.forEach { ruuviTagSensor in
            sensorSettingsTokens[ruuviTagSensor.id] = ruuviReactor.observe(
                ruuviTagSensor, { [weak self] change in
                    switch change {
                    case .update(let updateSensorSettings):
                        if let updateIndex = self?.sensorSettingsList.firstIndex(
                            where: { $0.id == updateSensorSettings.id }
                        ) {
                            self?.sensorSettingsList[updateIndex] = updateSensorSettings
                        } else {
                            self?.sensorSettingsList.append(updateSensorSettings)
                        }
                        if let luid = ruuviTagSensor.luid?.value {
                            self?.savedDate.removeValue(forKey: luid)
                        }
                    case .insert(let sensorSettings):
                        self?.sensorSettingsList.append(sensorSettings)
                        if let luid = ruuviTagSensor.luid?.value {
                            self?.savedDate.removeValue(forKey: luid)
                        }
                    case .delete(let deleteSensorSettings):
                        if let deleteIndex = self?.sensorSettingsList.firstIndex(
                            where: { $0.id == deleteSensorSettings.id }
                        ) {
                            self?.sensorSettingsList.remove(at: deleteIndex)
                        }
                    default:
                        break
                    }
                }
            )
        }
    }
}
