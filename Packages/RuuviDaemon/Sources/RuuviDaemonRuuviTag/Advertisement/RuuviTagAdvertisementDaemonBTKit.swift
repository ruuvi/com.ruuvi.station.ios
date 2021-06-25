import BTKit
import Foundation
import RuuviOntology
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviPool
import RuuviPersistence

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
    private var saveInterval: TimeInterval {
        return TimeInterval(settings.advertisementDaemonIntervalMinutes * 60)
    }

    @objc private class RuuviTagWrapper: NSObject {
        var device: RuuviTag
        init(device: RuuviTag) {
            self.device = device
        }
    }

    deinit {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        ruuviTagsToken?.invalidate()
        isOnToken?.invalidate()
        sensorSettingsTokens.forEach({ $0.invalidate() })
        sensorSettingsTokens.removeAll()
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
            .addObserver(forName: .isAdvertisementDaemonOnDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
                guard let sSelf = self else { return }
                if sSelf.settings.isAdvertisementDaemonOn {
                    sSelf.start()
                } else {
                    sSelf.stop()
                }
            }
    }

    public func start() {
        start { [weak self] in
            self?.ruuviTagsToken = self?.ruuviReactor.observe({ [weak self] change in
                guard let sSelf = self else { return }
                switch change {
                case .initial(let ruuviTags):
                    sSelf.ruuviTags = ruuviTags
                    sSelf.reloadSensorSettings()
                    sSelf.restartObserving()
                case .update(let ruuviTag):
                    if let index = sSelf.ruuviTags.firstIndex(of: ruuviTag) {
                        sSelf.ruuviTags[index] = ruuviTag
                    }
                    sSelf.restartObserving()
                case .insert(let ruuviTag):
                    sSelf.ruuviTags.append(ruuviTag)
                    sSelf.restartObserving()
                case .delete(let ruuviTag):
                    sSelf.ruuviTags.removeAll(where: { $0.id == ruuviTag.id })
                    sSelf.restartObserving()
                case .error(let error):
                    sSelf.post(error: .ruuviReactor(error))
                }
            })
        }
    }

    public func stop() {
        perform(#selector(RuuviTagAdvertisementDaemonBTKit.stopDaemon),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
    }

    @objc private func stopDaemon() {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()
        sensorSettingsTokens.forEach({ $0.invalidate() })
        sensorSettingsTokens.removeAll()
        ruuviTagsToken?.invalidate()
        stopWork()
    }
    private func reloadSensorSettings() {
        sensorSettingsList.removeAll()
        ruuviTags.forEach { ruuviTag in
            ruuviStorage.readSensorSettings(ruuviTag).on {[weak self] sensorSettings in
                if let sensorSettings = sensorSettings {
                    self?.sensorSettingsList.append(sensorSettings)
                }
            }
        }
    }

    private func restartObserving() {
        observeTokens.forEach({ $0.invalidate() })
        observeTokens.removeAll()

        sensorSettingsTokens.forEach({ $0.invalidate() })
        sensorSettingsTokens.removeAll()

        for ruuviTag in ruuviTags {
            guard let luid = ruuviTag.luid else { continue }
            observeTokens.append(foreground.observe(self,
                                                    uuid: luid.value,
                                                    options: [.callbackQueue(.untouch)]) {
                [weak self] (_, device) in
                guard let sSelf = self else { return }
                if let tag = device.ruuvi?.tag, !tag.isConnected {
                    sSelf.perform(#selector(RuuviTagAdvertisementDaemonBTKit.persist(wrapper:)),
                                  on: sSelf.thread,
                                  with: RuuviTagWrapper(device: tag),
                                  waitUntilDone: false,
                                  modes: [RunLoop.Mode.default.rawValue])
                }
            })
            sensorSettingsTokens.append(ruuviReactor.observe(ruuviTag, { [weak self] change in
                switch change {
                case .delete(let sensorSettings):
                    if let dIndex = self?.sensorSettingsList.firstIndex(
                        where: { $0.id == sensorSettings.id }
                    ) {
                        self?.sensorSettingsList.remove(at: dIndex)
                    }
                case .insert(let sensorSettings):
                    self?.sensorSettingsList.append(sensorSettings)
                    // remove last update timestamp to force add new record in db
                    self?.savedDate.removeValue(forKey: luid.value)
                case .update(let sensorSettings):
                    if let uIndex = self?.sensorSettingsList.firstIndex(
                        where: { $0.id == sensorSettings.id }
                    ) {
                        self?.sensorSettingsList[uIndex] = sensorSettings
                    } else {
                        self?.sensorSettingsList.append(sensorSettings)
                    }
                    self?.savedDate.removeValue(forKey: luid.value)
                default: break
                }
            }))
        }
    }

    @objc private func persist(wrapper: RuuviTagWrapper) {
        let uuid = wrapper.device.uuid
        if let date = savedDate[uuid] {
            if Date().timeIntervalSince(date) > saveInterval {
                persist(wrapper.device, uuid)
            }
        } else {
            persist(wrapper.device, uuid)
        }
    }

    private func post(error: RuuviDaemonError) {
        DispatchQueue.main.async {
            NotificationCenter
                .default
                .post(name: .RuuviTagAdvertisementDaemonDidFail,
                      object: nil,
                      userInfo: [RuuviTagAdvertisementDaemonDidFailKey.error: error])
        }
    }

    private func persist(_ record: RuuviTag, _ uuid: String) {
        let sensorSettings = self.sensorSettingsList
            .first(where: { ($0.luid?.any == record.luid?.any) || ($0.macId?.any == record.macId?.any) })
        ruuviPool.create(
            record
                .with(source: .advertisement)
                .with(sensorSettings: sensorSettings)
        ).on(failure: { [weak self] error in
            if case RuuviPoolError.ruuviPersistence(let persistenceError) = error {
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
        savedDate[uuid] = Date()
    }
}

extension NSObjectProtocol {
    func invalidate() {
        NotificationCenter
            .default
            .removeObserver(self)
    }
}
