// swiftlint:disable file_length

import BTKit
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviReactor
import RuuviService
import RuuviStorage

// swiftlint:disable:next type_body_length
public final class RuuviTagAdvertisementDaemonBTKit: RuuviDaemonWorker, RuuviTagAdvertisementDaemon {
    private let ruuviPool: RuuviPool
    private let ruuviStorage: RuuviStorage
    private let ruuviReactor: RuuviReactor
    private let foreground: BTForeground
    private let settings: RuuviLocalSettings
    private let flags: RuuviLocalFlags
    private let localSyncState: RuuviLocalSyncState
    private let gattService: GATTService
    private let widgetCache = WidgetSensorCache()
    private let persistenceGate = AdvertisementPersistenceGate()

    // Observation lifecycle and callbacks are serialized on the main queue.
    private var observationID: UUID?
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
        let device: RuuviTag
        let sensor: AnyRuuviTagSensor
        let settings: SensorSettings?
        let observationID: UUID
        let generation: UUID

        init(
            device: RuuviTag,
            sensor: AnyRuuviTagSensor,
            settings: SensorSettings?,
            observationID: UUID,
            generation: UUID
        ) {
            self.device = device
            self.sensor = sensor
            self.settings = settings
            self.observationID = observationID
            self.generation = generation
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
        settings: RuuviLocalSettings,
        flags: RuuviLocalFlags,
        localSyncState: RuuviLocalSyncState,
        gattService: GATTService
    ) {
        self.ruuviPool = ruuviPool
        self.ruuviStorage = ruuviStorage
        self.ruuviReactor = ruuviReactor
        self.foreground = foreground
        self.settings = settings
        self.flags = flags
        self.localSyncState = localSyncState
        self.gattService = gattService
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
        DispatchQueue.main.async { [weak self] in
            self?.startDaemon()
        }
    }

    private func startDaemon() {
        guard observationID == nil else { return }
        let observationID = UUID()
        self.observationID = observationID
        start {
            // No worker setup is needed: persistence arrives via selectors; observation state stays on main.
        }
        ruuviTagsToken = ruuviReactor.observe { [weak self] change in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.observationID == observationID else { return }
                self.handleSensorChange(change)
            }
        }
    }

    private func handleSensorChange(_ change: RuuviReactorChange<AnyRuuviTagSensor>) {
        switch change {
        case let .initial(ruuviTags):
            self.ruuviTags = ruuviTags
            reloadSensorSettings()
        case let .update(ruuviTag):
            persistenceGate.invalidate(sensorID: ruuviTag.id)
            if let index = ruuviTags.firstIndex(of: ruuviTag) {
                ruuviTags[index] = ruuviTag
            }
        case let .insert(ruuviTag):
            ruuviTags.append(ruuviTag)
        case let .delete(ruuviTag):
            ruuviTags.removeAll(where: { $0.id == ruuviTag.id })
        case let .error(error):
            post(error: .ruuviReactor(error))
            return
        }
        rebuildRuuviTagIndex()
        pruneCachedState(keeping: tagIdentifierValues())
        restartObserving()
    }

    public func stop() {
        DispatchQueue.main.async { [weak self] in
            self?.stopDaemon()
        }
    }

    public func restart() {
        DispatchQueue.main.async { [weak self] in
            self?.reloadSensors()
        }
    }

    private func reloadSensors() {
        guard let observationID else { return }
        ruuviStorage.readAll().on(success: { [weak self] sensors in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.observationID == observationID else { return }
                sensors.forEach { self.persistenceGate.invalidate(sensorID: $0.id) }
                self.ruuviTags = sensors
                self.rebuildRuuviTagIndex()
                self.pruneCachedState(keeping: self.tagIdentifierValues())
                self.restartObserving()
            }
        })
    }

    private func stopDaemon() {
        observationID = nil
        persistenceGate.syncSensors([])
        observeTokens.values.forEach { $0.invalidate() }
        observeTokens.removeAll()
        sensorSettingsTokens.values.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()
        ruuviTagsToken?.invalidate()
        ruuviTagsToken = nil
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
        // Keep removal from the widget cache atomic with invalidating queued advertisements.
        persistenceGate.syncSensors(Set(ruuviTags.map { $0.id })) {
            widgetCache.syncSensors(ruuviTags) { [weak self] sensor in
                self?.sensorSettings(for: sensor)
            }
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
        let observationID = observationID
        ruuviTags.forEach { persistenceGate.invalidate(sensorID: $0.id) }
        sensorSettingsList.removeAll()
        for ruuviTag in ruuviTags {
            ruuviStorage.readSensorSettings(ruuviTag).on { [weak self] sensorSettings in
                DispatchQueue.main.async { [weak self] in
                    guard self?.observationID == observationID else { return }
                    if let sensorSettings {
                        self?.persistenceGate.invalidate(sensorID: ruuviTag.id)
                        self?.sensorSettingsList.append(sensorSettings)
                    }
                }
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func restartObserving() {
        guard let observationID else { return }
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
                    guard let tag = device.ruuvi?.tag else { return }
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.observationID == observationID,
                              let thread = self.thread, !thread.isCancelled else { return }
                        self.syncHistoryIfEligible(for: tag)
                        guard !tag.isConnected,
                              let sensor = self.ruuviTagsByLuid[luid.any],
                              let generation = self.persistenceGate.generation(for: sensor.id) else { return }
                        // Resolve collection state on main before handing immutable values to the worker.
                        let wrapper = RuuviTagWrapper(
                            device: tag,
                            sensor: sensor,
                            settings: self.sensorSettings(for: sensor),
                            observationID: observationID,
                            generation: generation
                        )
                        self.perform(
                            #selector(RuuviTagAdvertisementDaemonBTKit.persist(wrapper:)),
                            on: thread,
                            with: wrapper,
                            waitUntilDone: false,
                            modes: [RunLoop.Mode.default.rawValue]
                        )
                    }
                }
            }

            if sensorSettingsTokens[ruuviTag.id] == nil {
                sensorSettingsTokens[ruuviTag.id] = ruuviReactor.observe(ruuviTag) { [weak self] change in
                    DispatchQueue.main.async { [weak self] in
                        guard self?.observationID == observationID else { return }
                        self?.persistenceGate.invalidate(sensorID: ruuviTag.id)
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
    }

    // Called only for live Bluetooth observations, never cached or cloud records.
    // Keep eligibility and enqueueing on the main queue, shared with graph actions.
    private func syncHistoryIfEligible(for record: RuuviTag) {
        guard settings.appIsOnForeground, settings.isAdvertisementDaemonOn,
              flags.autoSyncGattHistoryForRuuviAir,
              let luid = record.luid,
              let sensor = ruuviTags.first(where: { $0.luid?.value == luid.value }),
              !sensor.isCloud,
              let macId = sensor.macId,
              !localSyncState.isAutoGattSyncSuppressed(for: macId),
              !gattService.isSyncingLogs(with: luid.value)
        else { return }
        let format = RuuviDataFormat.dataFormat(from: record.version)
        guard format == .e1 || format == .v6 else { return }
        if !flags.allowConcurrentGattSyncForMultipleSensors,
           gattService.isSyncingLogs() {
            return
        }

        let now = Date()
        let lastSync = localSyncState.getGattSyncDate(for: macId)
        let lastAttempt = localSyncState.getAutoGattSyncAttemptDate(for: macId)
        guard AutomaticGattSyncPolicy.isEligible(
            now: now,
            lastSync: lastSync,
            lastAttempt: lastAttempt,
            cooldownMinutes: flags.autoSyncGattHistoryForRuuviAirMinimumLastSyncDateAgeMinutes
        ) else { return }
        let from = AutomaticGattSyncPolicy.syncFrom(
            now: now,
            lastSync: lastSync,
            historyHours: settings.dataPruningOffsetHours
        )
        localSyncState.setAutoGattSyncAttemptDate(now, for: macId)
        localSyncState.setHasLoggedFirstAutoSyncGattHistoryForRuuviAir(true, for: macId)
        gattService.syncLogs(
            uuid: luid.value,
            mac: macId.value,
            firmware: record.version,
            from: from,
            settings: sensorSettings(for: sensor),
            progress: nil,
            timeouts: GATTServiceTimeouts(
                connection: settings.connectionTimeout,
                service: settings.serviceTimeout
            )
        ).on(success: { [weak self] completed in
            guard completed else { return }
            DispatchQueue.main.async {
                guard self?.localSyncState.isAutoGattSyncSuppressed(for: macId) == false else { return }
                self?.localSyncState.setGattSyncDate(now, for: macId)
            }
        })
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
        persistenceGate.performIfValid(sensorID: wrapper.sensor.id, generation: wrapper.generation) {
            persistIfCurrent(wrapper: wrapper)
        }
    }

    private func persistIfCurrent(wrapper: RuuviTagWrapper) {
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
                persist(wrapper)
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
                persist(wrapper)
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

    private func persist(_ wrapper: RuuviTagWrapper) {
        let record = wrapper.device
        let uuid = record.uuid
        widgetCache.upsert(
            sensor: wrapper.sensor,
            record: snapshot(from: record, source: .advertisement),
            settings: wrapper.settings
        )

        // Do not store advertisement for history only if it is v6 firmware and legacy advertisement.
        if record.version == 0x06 {
            createLatestRecord(with: wrapper)
        } else {
            createRecord(with: wrapper)
        }
        stateQueue.sync {
            savedDate[uuid] = Date()
            advertisementSequence.removeValue(forKey: uuid)
        }
    }

    private func createRecord(with wrapper: RuuviTagWrapper) {
        let record = wrapper.device
        ruuviPool.create(
            record
                .with(source: .advertisement)
        ).on(success: { _ in
            self.createLatestRecord(with: wrapper)
        }, failure: { [weak self] error in
            DispatchQueue.main.async { [weak self] in
                self?.handlePersistenceFailure(error, for: wrapper)
            }
        })
    }

    private func handlePersistenceFailure(_ error: RuuviPoolError, for wrapper: RuuviTagWrapper) {
        guard observationID == wrapper.observationID,
              persistenceGate.generation(for: wrapper.sensor.id) == wrapper.generation else { return }
        if case let RuuviPoolError.ruuviPersistence(persistenceError) = error {
            switch persistenceError {
            case .failedToFindRuuviTag:
                ruuviTags.removeAll(where: { $0.id == wrapper.device.uuid })
                rebuildRuuviTagIndex()
                pruneCachedState(keeping: tagIdentifierValues())
                restartObserving()
            default:
                break
            }
        }
        post(error: .ruuviPool(error))
    }

    private func createLatestRecord(with wrapper: RuuviTagWrapper) {
        persistenceGate.performIfValid(sensorID: wrapper.sensor.id, generation: wrapper.generation) {
            ruuviStorage.readLatest(wrapper.sensor).on(success: { [weak self] localRecord in
                guard let self else { return }
                self.persistenceGate.performIfValid(sensorID: wrapper.sensor.id, generation: wrapper.generation) {
                    guard localRecord != nil else {
                        self.ruuviPool.createLast(wrapper.device)
                        return
                    }
                    var advertisement: RuuviTagSensorRecord = wrapper.device.with(source: .advertisement)
                    if let macId = wrapper.sensor.macId {
                        advertisement = advertisement.with(macId: macId)
                    }
                    self.ruuviPool.updateLast(advertisement)
                }
            })
        }
    }
}

// swiftlint:enable file_length
