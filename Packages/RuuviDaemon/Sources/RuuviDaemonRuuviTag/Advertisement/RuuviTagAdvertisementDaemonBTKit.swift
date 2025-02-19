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
    private let idPersistence: RuuviLocalIDs
    private let settings: RuuviLocalSettings

    private var ruuviTagsToken: RuuviReactorToken?
    private var observeTokens = [ObservationToken]()
    private var ruuviTagPropertiesToken: NSObjectProtocol?
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
        invalidateAndClearTagsAndSettingsTokens()
        ruuviTagsToken?.invalidate()
        if let isOnToken {
            NotificationCenter.default.removeObserver(isOnToken)
        }
        if let cloudModeOnToken {
            NotificationCenter.default.removeObserver(cloudModeOnToken)
        }
        if let daemonRestartToken {
            NotificationCenter.default.removeObserver(daemonRestartToken)
        }
        if let ruuviTagPropertiesToken {
            NotificationCenter.default.removeObserver(ruuviTagPropertiesToken)
        }
    }

    // swiftlint:disable:next function_body_length
    public init(
        ruuviPool: RuuviPool,
        ruuviStorage: RuuviStorage,
        ruuviReactor: RuuviReactor,
        foreground: BTForeground,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings
    ) {
        self.ruuviPool = ruuviPool
        self.ruuviStorage = ruuviStorage
        self.ruuviReactor = ruuviReactor
        self.idPersistence = idPersistence
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

        ruuviTagPropertiesToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagPropertiesExtendedLUIDChanged,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.restartObserving()
                }
            )
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
        invalidateAndClearTagsAndSettingsTokens()
        ruuviTagsToken?.invalidate()
        stopWork()
    }

    private func invalidateAndClearTagsAndSettingsTokens() {
        observeTokens.forEach { $0.invalidate() }
        observeTokens.removeAll()

        sensorSettingsTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()
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

    private func restartObserving() {
        // Clear existing observation tokens
        invalidateAndClearTagsAndSettingsTokens()

        for ruuviTag in ruuviTags {
            // Skip cloud tags when cloud mode is enabled
            if settings.cloudModeEnabled && ruuviTag.isCloud {
                continue
            }

            // Get the appropriate identifier
            guard let luid = getObservableIdentifier(for: ruuviTag) else {
                continue
            }

            // Setup tag observation
            setupTagObservation(for: luid)

            // Setup settings observation
            setupSettingsObservation(for: ruuviTag, luid: luid)
        }
    }

    private func getObservableIdentifier(for ruuviTag: AnyRuuviTagSensor) -> LocalIdentifier? {
        if let macId = ruuviTag.macId,
           let extendedLuid = idPersistence.extendedLuid(for: macId) {
            return extendedLuid
        } else if let luid = ruuviTag.luid {
            return luid
        }
        return nil
    }

    private func setupTagObservation(for luid: LocalIdentifier) {
        let token = foreground.observe(
            self,
            uuid: luid.value,
            options: [.callbackQueue(.untouch)]
        ) { [weak self] _, device in
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
        }
        observeTokens.append(token)
    }

    private func setupSettingsObservation(for ruuviTag: AnyRuuviTagSensor, luid: LocalIdentifier) {
        let token = ruuviReactor.observe(ruuviTag) { [weak self] change in
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
        }
        sensorSettingsTokens.append(token)
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
        // If the tag chart is on foreground store all advertisements
        // Otherwise respect the settings
        guard wrapper.device.luid != nil else { return }
        if settings.appIsOnForeground {
            if let previous = advertisementSequence[uuid], let previous {
                if let next = wrapper.device.measurementSequenceNumber, next > previous {
                    persist(wrapper.device, uuid)
                }
            } else {
                // Tags with data format 3 and E0 doesn't sent duplicates packets*
                if wrapper.device.version == 3 || wrapper.device.version == 224 {
                    persist(wrapper.device, uuid)
                }
                advertisementSequence[uuid] = wrapper.device.measurementSequenceNumber
            }
        } else {
            if let date = savedDate[uuid] {
                if Date().timeIntervalSince(date) > saveInterval {
                    persist(wrapper.device, uuid)
                }
            } else {
                persist(wrapper.device, uuid)
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
        createRecord(with: record, uuid: uuid)
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
            $0.macId?.value == record.macId?.value
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
