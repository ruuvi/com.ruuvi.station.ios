// swiftlint:disable file_length

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
    private let widgetCache = WidgetSensorCache()

    private var ruuviTagsToken: RuuviReactorToken?
    private var observeTokens = [String: ObservationToken]()
    private var sensorSettingsTokens = [String: RuuviReactorToken]()
    private var ruuviTags = [AnyRuuviTagSensor]()
    private var ruuviTagsByLuid = [AnyLocalIdentifier: AnyRuuviTagSensor]()
    private var sensorSettingsList = [SensorSettings]()
    private var savedDate = [String: Date]() // uuid:date
    private let stateQueue = DispatchQueue(label: "RuuviTagAdvertisementDaemonBTKit.stateQueue")
    private var isOnToken: NSObjectProtocol?
    private var cloudModeOnToken: NSObjectProtocol?
    private var daemonRestartToken: NSObjectProtocol?
    private var saveInterval: TimeInterval {
        TimeInterval(settings.advertisementDaemonIntervalMinutes * 60)
    }

    private var advertisementSequence = [String: Int]() // uuid: int

    @objc private class RuuviTagWrapper: NSObject {
        var device: RuuviTag
        init(device: RuuviTag) {
            self.device = device
        }
    }

    deinit {
        observeTokens.values.forEach { $0.invalidate() }
        observeTokens.removeAll()
        ruuviTagsToken?.invalidate()
        if let isOnToken {
            NotificationCenter.default.removeObserver(isOnToken)
        }
        sensorSettingsTokens.values.forEach { $0.invalidate() }
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
                    sSelf.rebuildRuuviTagIndex()
                    sSelf.pruneCachedState(keeping: sSelf.tagIdentifierValues())
                    sSelf.reloadSensorSettings()
                    sSelf.restartObserving()
                case let .update(ruuviTag):
                    if let index = sSelf.ruuviTags.firstIndex(of: ruuviTag) {
                        sSelf.ruuviTags[index] = ruuviTag
                    }
                    sSelf.rebuildRuuviTagIndex()
                    sSelf.pruneCachedState(keeping: sSelf.tagIdentifierValues())
                    sSelf.restartObserving()
                case let .insert(ruuviTag):
                    sSelf.ruuviTags.append(ruuviTag)
                    sSelf.rebuildRuuviTagIndex()
                    sSelf.pruneCachedState(keeping: sSelf.tagIdentifierValues())
                    sSelf.restartObserving()
                case let .delete(ruuviTag):
                    sSelf.ruuviTags.removeAll(where: { $0.id == ruuviTag.id })
                    sSelf.rebuildRuuviTagIndex()
                    sSelf.pruneCachedState(keeping: sSelf.tagIdentifierValues())
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
            self?.rebuildRuuviTagIndex()
            self?.pruneCachedState(keeping: self?.tagIdentifierValues() ?? [])
            self?.restartObserving()
        })
    }

    @objc private func stopDaemon() {
        observeTokens.values.forEach { $0.invalidate() }
        observeTokens.removeAll()
        sensorSettingsTokens.values.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()
        ruuviTagsToken?.invalidate()
        stopWork()
    }

    private func rebuildRuuviTagIndex() {
        var luidIndex = [AnyLocalIdentifier: AnyRuuviTagSensor]()
        for tag in ruuviTags {
            if let luid = tag.luid?.any {
                luidIndex[luid] = tag
            }
        }
        ruuviTagsByLuid = luidIndex
        widgetCache.syncSensors(ruuviTags) { [weak self] sensor in
            self?.sensorSettings(for: sensor)
        }
    }

    private func tagIdentifierValues() -> Set<String> {
        var values = Set<String>()
        values.reserveCapacity(ruuviTags.count * 2)
        for tag in ruuviTags {
            values.insert(tag.id)
            if let luid = tag.luid?.value {
                values.insert(luid)
            }
            if let mac = tag.macId?.value {
                values.insert(mac)
            }
        }
        return values
    }

    private func pruneCachedState(keeping identifierValues: Set<String>) {
        stateQueue.sync {
            let savedDateKeys = savedDate.keys.filter { !identifierValues.contains($0) }
            savedDateKeys.forEach { savedDate.removeValue(forKey: $0) }
            let sequenceKeys = advertisementSequence.keys.filter { !identifierValues.contains($0) }
            sequenceKeys.forEach { advertisementSequence.removeValue(forKey: $0) }
        }
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func restartObserving() {
        let desiredTags = ruuviTags.filter { !(settings.cloudModeEnabled && $0.isCloud) }
        let desiredLuidValues = Set(desiredTags.compactMap { $0.luid?.value })
        let desiredTagIds = Set(desiredTags.map { $0.id })

        let observeTokensToRemove = observeTokens.filter { !desiredLuidValues.contains($0.key) }
        for (luidValue, token) in observeTokensToRemove {
            token.invalidate()
            observeTokens.removeValue(forKey: luidValue)
        }

        let sensorSettingsTokensToRemove = sensorSettingsTokens.filter { !desiredTagIds.contains($0.key) }
        for (tagId, token) in sensorSettingsTokensToRemove {
            token.invalidate()
            sensorSettingsTokens.removeValue(forKey: tagId)
        }

        for ruuviTag in desiredTags {
            guard let luid = ruuviTag.luid else { continue }
            if observeTokens[luid.value] == nil {
                observeTokens[luid.value] = foreground.observe(
                    self,
                    uuid: luid.value,
                    options: [.callbackQueue(.untouch)]
                ) { [weak self] _, device in
                    guard let sSelf = self, sSelf.thread != nil else { return }
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
            }

            if sensorSettingsTokens[ruuviTag.id] == nil {
                sensorSettingsTokens[ruuviTag.id] = ruuviReactor.observe(ruuviTag) { [weak self] change in
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
                        _ = self?.stateQueue.sync {
                            self?.savedDate.removeValue(forKey: luid.value)
                        }
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
            }
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
        _ = stateQueue.sync {
            savedDate.removeValue(forKey: luid.value)
        }
    }

    private func sensorSettings(
        for ruuviTagSensor: AnyRuuviTagSensor
    ) -> SensorSettings? {
        if let sensorLuid = ruuviTagSensor.luid?.any {
            if let settings = sensorSettingsList.first(where: { $0.luid?.any == sensorLuid }) {
                return settings
            }
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

    @objc private func persist(wrapper: RuuviTagWrapper) {
        let uuid = wrapper.device.uuid
        guard wrapper.device.luid != nil else { return }
        if settings.appIsOnForeground {
            let shouldPersist: Bool
            shouldPersist = stateQueue.sync {
                if let previous = advertisementSequence[uuid],
                   let next = wrapper.device.measurementSequenceNumber {
                    // Persist only if sequence number changes, handling wrap-around
                    return next != previous
                }
                // Persist first advertisement when no previous sequence exists
                return true
            }
            if shouldPersist {
                persist(wrapper.device, uuid)
                stateQueue.sync {
                    if let sequence = wrapper.device.measurementSequenceNumber {
                        advertisementSequence[uuid] = sequence
                    } else {
                        advertisementSequence.removeValue(forKey: uuid)
                    }
                }
            }
        } else {
            // Background: persist based on time interval
            let shouldPersist = stateQueue.sync {
                if let date = savedDate[uuid] {
                    return Date().timeIntervalSince(date) > saveInterval
                } else {
                    return true
                }
            }
            if shouldPersist {
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
        let tagExists: Bool = {
            if let recordLuid = record.luid?.any {
                if ruuviTagsByLuid[recordLuid] != nil {
                    return true
                }
                if ruuviTags.contains(where: { $0.luid?.any == recordLuid }) {
                    return true
                }
            }
            if let recordMac = record.mac {
                return ruuviTags.contains { $0.macId?.value == recordMac }
            }
            return false
        }()

        guard tagExists else {
            return
        }

        let ruuviTagSensor: AnyRuuviTagSensor? = {
            if let recordLuid = record.luid?.any {
                if let match = ruuviTagsByLuid[recordLuid] {
                    return match
                }
                return ruuviTags.first(where: { $0.luid?.any == recordLuid })
            }
            if let recordMac = record.macId?.any {
                return ruuviTags.first(where: { $0.macId?.any == recordMac })
            }
            return nil
        }()
        if let ruuviTagSensor {
            let settings = sensorSettings(for: ruuviTagSensor)
            widgetCache.upsert(
                sensor: ruuviTagSensor,
                record: snapshot(from: record, source: .advertisement),
                settings: settings
            )
        }

        // Do not store advertisement for history only if it is v6 firmware and legacy advertisement.
        if record.version == 0x06 {
            createLatestRecord(with: record)
        } else {
            createRecord(with: record, uuid: uuid)
        }
        stateQueue.sync {
            savedDate[uuid] = Date()
            advertisementSequence.removeValue(forKey: uuid)
        }
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
                    self?.rebuildRuuviTagIndex()
                    self?.pruneCachedState(keeping: self?.tagIdentifierValues() ?? [])
                    self?.restartObserving()
                default:
                    break
                }
            }
            self?.post(error: .ruuviPool(error))
        })
    }

    private func createLatestRecord(with record: RuuviTag) {
        let ruuviTag: AnyRuuviTagSensor? = {
            if let recordLuid = record.luid?.any {
                if let match = ruuviTagsByLuid[recordLuid] {
                    return match
                }
                return ruuviTags.first(where: { $0.luid?.any == recordLuid })
            }
            return nil
        }()
        if let ruuviTag {
            ruuviStorage.readLatest(ruuviTag).on(success: { [weak self] localRecord in
                guard localRecord != nil
                else {
                    self?.ruuviPool.createLast(record)
                    return
                }
                var advertisement: RuuviTagSensorRecord = record.with(source: .advertisement)
                if let macId = ruuviTag.macId {
                    advertisement = advertisement.with(macId: macId)
                }
                self?.ruuviPool.updateLast(advertisement)
            })
        }
    }
}

// swiftlint:enable file_length
