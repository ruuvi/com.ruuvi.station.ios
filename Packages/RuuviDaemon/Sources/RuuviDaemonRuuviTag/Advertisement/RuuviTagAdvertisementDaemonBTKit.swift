import BTKit
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviReactor
import RuuviStorage

// swiftlint:disable:next type_body_length
public final class RuuviTagAdvertisementDaemonBTKit: RuuviDaemonWorker, RuuviTagAdvertisementDaemon {
    private let ruuviPool: RuuviPool
    private let ruuviStorage: RuuviStorage
    private let ruuviReactor: RuuviReactor
    private let foreground: BTForeground
    private let settings: RuuviLocalSettings

    private var ruuviTagsToken: RuuviReactorToken?
    private var observeTokens = [ObservationToken]()
    private var sensorSettingsTokens = [RuuviReactorToken]()
    private var ruuviTags = [AnyRuuviTagSensor]()
    private var sensorSettingsList = [SensorSettings]()
    private var savedDate = [String: Date]() // uuid:date
    private var isOnToken: NSObjectProtocol?
    private var cloudModeOnToken: NSObjectProtocol?
    private var daemonRestartToken: NSObjectProtocol?
    private var saveInterval: TimeInterval {
        TimeInterval(settings.advertisementDaemonIntervalMinutes * 60)
    }

    private var advertisementSequence = [String: Int?]() // uuid: int

    @objc private class RuuviTagWrapper: NSObject {
        var device: RuuviTag
        init(device: RuuviTag) {
            self.device = device
        }
    }

    deinit {
        observeTokens.forEach { $0.invalidate() }
        observeTokens.removeAll()
        ruuviTagsToken?.invalidate()
        if let isOnToken {
            NotificationCenter.default.removeObserver(isOnToken)
        }
        sensorSettingsTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()
        if let cloudModeOnToken {
            NotificationCenter.default.removeObserver(cloudModeOnToken)
        }
        if let daemonRestartToken {
            NotificationCenter.default.removeObserver(daemonRestartToken)
        }
    }

    public init(
        ruuviPool: RuuviPool,
        ruuviStorage: RuuviStorage,
        ruuviReactor: RuuviReactor,
        foreground: BTForeground,
        settings: RuuviLocalSettings
    ) {
        self.ruuviPool = ruuviPool
        self.ruuviStorage = ruuviStorage
        self.ruuviReactor = ruuviReactor
        self.foreground = foreground
        self.settings = settings
        super.init()
        isOnToken = NotificationCenter
            .default
            .addObserver(
                forName: .isAdvertisementDaemonOnDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self else { return }
                if sSelf.settings.isAdvertisementDaemonOn {
                    sSelf.start()
                } else {
                    sSelf.stop()
                }
            }

        cloudModeOnToken = NotificationCenter
            .default
            .addObserver(
                forName: .CloudModeDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self else { return }
                sSelf.restartObserving()
            }

        daemonRestartToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagAdvertisementDaemonShouldRestart,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let sSelf = self else { return }
                sSelf.restart()
            }
    }

    public func start() {
        start { [weak self] in
            self?.ruuviTagsToken = self?.ruuviReactor.observe { [weak self] change in
                guard let sSelf = self else { return }
                switch change {
                case let .initial(ruuviTags):
                    sSelf.ruuviTags = ruuviTags
                    sSelf.reloadSensorSettings()
                    sSelf.restartObserving()
                case let .update(ruuviTag):
                    if let index = sSelf.ruuviTags.firstIndex(of: ruuviTag) {
                        sSelf.ruuviTags[index] = ruuviTag
                    }
                    sSelf.restartObserving()
                case let .insert(ruuviTag):
                    sSelf.ruuviTags.append(ruuviTag)
                    sSelf.restartObserving()
                case let .delete(ruuviTag):
                    sSelf.ruuviTags.removeAll(where: { $0.id == ruuviTag.id })
                    sSelf.restartObserving()
                case let .error(error):
                    sSelf.post(error: .ruuviReactor(error))
                }
            }
        }
    }

    public func stop() {
        perform(
            #selector(RuuviTagAdvertisementDaemonBTKit.stopDaemon),
            on: thread,
            with: nil,
            waitUntilDone: false,
            modes: [RunLoop.Mode.default.rawValue]
        )
    }

    public func restart() {
        ruuviStorage.readAll().on(success: { [weak self] sensors in
            self?.ruuviTags = sensors
            self?.restartObserving()
        })
    }

    @objc private func stopDaemon() {
        observeTokens.forEach { $0.invalidate() }
        observeTokens.removeAll()
        sensorSettingsTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()
        ruuviTagsToken?.invalidate()
        stopWork()
    }

    private func reloadSensorSettings() {
        sensorSettingsList.removeAll()
        ruuviTags.forEach { ruuviTag in
            ruuviStorage.readSensorSettings(ruuviTag).on { [weak self] sensorSettings in
                if let sensorSettings {
                    self?.sensorSettingsList.append(sensorSettings)
                }
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func restartObserving() {
        observeTokens.forEach { $0.invalidate() }
        observeTokens.removeAll()

        sensorSettingsTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()

        for ruuviTag in ruuviTags {
            let shouldAvoidObserving = settings.cloudModeEnabled && ruuviTag.isCloud
            if shouldAvoidObserving {
                continue
            }
            guard let luid = ruuviTag.luid else { continue }
            observeTokens.append(foreground.observe(
                self,
                uuid: luid.value,
                options: [.callbackQueue(.untouch)]
            ) {
                [weak self] _, device in
                guard let sSelf = self else { return }
                if let tag = device.ruuvi?.tag, !tag.isConnected {
                    sSelf.perform(
                        #selector(RuuviTagAdvertisementDaemonBTKit.persist(wrapper:)),
                        on: sSelf.thread,
                        with: RuuviTagWrapper(device: tag),
                        waitUntilDone: false,
                        modes: [RunLoop.Mode.default.rawValue]
                    )
                }
            })
            sensorSettingsTokens.append(ruuviReactor.observe(ruuviTag) { [weak self] change in
                switch change {
                case let .delete(sensorSettings):
                    if let dIndex = self?.sensorSettingsList.firstIndex(
                        where: { $0.id == sensorSettings.id }
                    ) {
                        self?.sensorSettingsList.remove(at: dIndex)
                    }
                case let .insert(sensorSettings):
                    self?.sensorSettingsList.append(sensorSettings)
                    // remove last update timestamp to force add new record in db
                    self?.savedDate.removeValue(forKey: luid.value)
                case let .update(sensorSettings):
                    self?.updateSensorSettings(sensorSettings, luid)
                case let .initial(initialSensorSettings):
                    initialSensorSettings.forEach {
                        self?.updateSensorSettings($0, luid)
                    }
                case let .error(error):
                    self?.post(error: .ruuviReactor(error))
                }
            })
        }
    }

    private func updateSensorSettings(_ sensorSettings: SensorSettings, _ luid: LocalIdentifier) {
        if let uIndex = sensorSettingsList.firstIndex(
            where: { $0.id == sensorSettings.id }
        ) {
            sensorSettingsList[uIndex] = sensorSettings
        } else {
            sensorSettingsList.append(sensorSettings)
        }
        savedDate.removeValue(forKey: luid.value)
    }

    @objc private func persist(wrapper: RuuviTagWrapper) {
        let uuid = wrapper.device.uuid
        guard wrapper.device.luid != nil else { return }
        if settings.appIsOnForeground {
            let shouldPersist: Bool
            if let previous = advertisementSequence[uuid],
                let next = wrapper.device.measurementSequenceNumber {
                // Persist only if sequence number changes, handling wrap-around
                shouldPersist = next != previous
            } else {
                // Persist first advertisement when no previous sequence exists
                shouldPersist = true
            }
            if shouldPersist {
                persist(wrapper.device, uuid)
                advertisementSequence[uuid] = wrapper.device.measurementSequenceNumber
            }
        } else {
            // Background: persist based on time interval
            if let date = savedDate[uuid] {
                if Date().timeIntervalSince(date) > saveInterval {
                    persist(wrapper.device, uuid)
                    savedDate[uuid] = Date()
                }
            } else {
                persist(wrapper.device, uuid)
                savedDate[uuid] = Date()
            }
        }
    }

    private func post(error: RuuviDaemonError) {
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(
                    name: .RuuviTagAdvertisementDaemonDidFail,
                    object: nil,
                    userInfo: [RuuviTagAdvertisementDaemonDidFailKey.error: error]
                )
        }
    }

    private func persist(_ record: RuuviTag, _ uuid: String) {
        // Do not store advertisement for history only if it is F0 firmware and legacy advertisement.
        if record.version == 0xF0 {
            createLatestRecord(with: record)
        } else {
            createRecord(with: record, uuid: uuid)
        }
        savedDate[uuid] = Date()
        advertisementSequence[uuid] = nil
    }

    private func createRecord(with record: RuuviTag, uuid: String) {
        ruuviPool.create(
            record
                .with(source: .advertisement)
        ).on(success: { _ in
            self.createLatestRecord(with: record)
        }, failure: { [weak self] error in
            if case let RuuviPoolError.ruuviPersistence(persistenceError) = error {
                switch persistenceError {
                case .failedToFindRuuviTag:
                    self?.ruuviTags.removeAll(where: { $0.id == uuid })
                    self?.restartObserving()
                default:
                    break
                }
            }
            self?.post(error: .ruuviPool(error))
        })
    }

    private func createLatestRecord(with record: RuuviTag) {
        if let ruuviTag = ruuviTags.first(where: {
            if let luid = $0.luid?.value, let recordLuid = record.luid?.value,
               luid == recordLuid {
                true
            } else {
                false
            }
        }) {
            ruuviStorage.readLatest(ruuviTag).on(success: { [weak self] localRecord in
                let advertisement = record.with(source: .advertisement)
                guard localRecord != nil
                else {
                    self?.ruuviPool.createLast(record)
                    return
                }
                self?.ruuviPool.updateLast(advertisement)
            })
        }
    }
}
