// swiftlint:disable file_length

import BTKit
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviReactor
import RuuviStorage

enum RuuviTagAdvertisementRecordPlan: Equatable {
    case historyAndLatest
    case latestOnly
}

enum RuuviTagAdvertisementLatestRecordPlan {
    case createLast(RuuviTagSensorRecord)
    case updateLast(RuuviTagSensorRecord)
}

protocol AdvertisementForegrounding {
    @discardableResult
    func observe<T: AnyObject>(
        _ observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        closure: @escaping (T, BTDevice) -> Void
    ) -> DaemonObservationToken
}

private struct AdvertisementForegroundAdapter: AdvertisementForegrounding {
    let foreground: BTForeground

    func observe<T: AnyObject>(
        _ observer: T,
        uuid: String,
        options: BTScannerOptionsInfo?,
        closure: @escaping (T, BTDevice) -> Void
    ) -> DaemonObservationToken {
        let token = foreground.observe(
            observer,
            uuid: uuid,
            options: options,
            closure: closure
        )
        return DaemonObservationToken {
            token.invalidate()
        }
    }
}

struct RuuviTagAdvertisementDaemonCore {
    static func rebuildRuuviTagIndex(
        from ruuviTags: [AnyRuuviTagSensor]
    ) -> [AnyLocalIdentifier: AnyRuuviTagSensor] {
        var luidIndex = [AnyLocalIdentifier: AnyRuuviTagSensor]()
        for tag in ruuviTags {
            if let luid = tag.luid?.any {
                luidIndex[luid] = tag
            }
        }
        return luidIndex
    }

    static func tagIdentifierValues(from ruuviTags: [AnyRuuviTagSensor]) -> Set<String> {
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

    static func pruneState(
        savedDate: [String: Date],
        advertisementSequence: [String: Int],
        keeping identifierValues: Set<String>
    ) -> (
        savedDate: [String: Date],
        advertisementSequence: [String: Int]
    ) {
        (
            savedDate: savedDate.filter { identifierValues.contains($0.key) },
            advertisementSequence: advertisementSequence.filter { identifierValues.contains($0.key) }
        )
    }

    static func removeCachedSensor(
        matching record: RuuviTag,
        fallbackUUID: String,
        ruuviTagsByLuid: [AnyLocalIdentifier: AnyRuuviTagSensor],
        ruuviTags: [AnyRuuviTagSensor]
    ) -> [AnyRuuviTagSensor] {
        if let cachedSensor = matchingSensor(
            for: record,
            ruuviTagsByLuid: ruuviTagsByLuid,
            ruuviTags: ruuviTags
        ) {
            return ruuviTags.filter { sensor in
                sensor.id != cachedSensor.id
                    && sensor.luid?.any != cachedSensor.luid?.any
                    && sensor.macId?.any != cachedSensor.macId?.any
            }
        }
        return ruuviTags.filter { sensor in
            sensor.id != fallbackUUID && sensor.luid?.value != fallbackUUID
        }
    }

    static func sensorSettings(
        for ruuviTagSensor: AnyRuuviTagSensor,
        in sensorSettingsList: [SensorSettings]
    ) -> SensorSettings? {
        if let sensorLuid = ruuviTagSensor.luid?.any,
           let settings = sensorSettingsList.first(where: { $0.luid?.any == sensorLuid }) {
            return settings
        }
        if let sensorMac = ruuviTagSensor.macId?.any {
            return sensorSettingsList.first(where: { $0.macId?.any == sensorMac })
        }
        return nil
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

    static func shouldPersist(
        appIsOnForeground: Bool,
        uuid: String,
        measurementSequenceNumber: Int?,
        lastSequenceNumber: Int?,
        lastSavedDate: Date?,
        saveInterval: TimeInterval,
        now: Date = Date()
    ) -> Bool {
        if appIsOnForeground {
            if let previous = lastSequenceNumber,
               let next = measurementSequenceNumber {
                return next != previous
            }
            return true
        }
        guard let date = lastSavedDate else {
            return true
        }
        return now.timeIntervalSince(date) > saveInterval && !uuid.isEmpty
    }

    static func matchingSensor(
        for record: RuuviTag,
        ruuviTagsByLuid: [AnyLocalIdentifier: AnyRuuviTagSensor],
        ruuviTags: [AnyRuuviTagSensor]
    ) -> AnyRuuviTagSensor? {
        if let recordLuid = record.luid?.any {
            if let match = ruuviTagsByLuid[recordLuid] {
                return match
            }
            if let match = ruuviTags.first(where: { $0.luid?.any == recordLuid }) {
                return match
            }
        }
        if let recordMac = record.macId?.any {
            return ruuviTags.first(where: { $0.macId?.any == recordMac })
        }
        return nil
    }

    static func recordPlan(for record: RuuviTag) -> RuuviTagAdvertisementRecordPlan {
        record.version == 0x06 ? .latestOnly : .historyAndLatest
    }

    static func latestRecordPlan(
        for record: RuuviTag,
        sensor: AnyRuuviTagSensor,
        localRecord: RuuviTagSensorRecord?
    ) -> RuuviTagAdvertisementLatestRecordPlan {
        guard localRecord != nil else {
            return .createLast(record)
        }
        var advertisement: RuuviTagSensorRecord = record.with(source: .advertisement)
        if let macId = sensor.macId {
            advertisement = advertisement.with(macId: macId)
        }
        return .updateLast(advertisement)
    }
}

// swiftlint:disable:next type_body_length
public final class RuuviTagAdvertisementDaemonBTKit: RuuviDaemonWorker, RuuviTagAdvertisementDaemon {
    private let ruuviPool: RuuviPool
    private let ruuviStorage: RuuviStorage
    private let ruuviReactor: RuuviReactor
    private let foreground: any AdvertisementForegrounding
    private let settings: RuuviLocalSettings
    private let widgetCache = WidgetSensorCache()

    private var ruuviTagsToken: RuuviReactorToken?
    private var observeTokens = [String: DaemonObservationToken]()
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

    public convenience init(
        ruuviPool: RuuviPool,
        ruuviStorage: RuuviStorage,
        ruuviReactor: RuuviReactor,
        foreground: BTForeground,
        settings: RuuviLocalSettings
    ) {
        self.init(
            ruuviPool: ruuviPool,
            ruuviStorage: ruuviStorage,
            ruuviReactor: ruuviReactor,
            foreground: AdvertisementForegroundAdapter(foreground: foreground),
            settings: settings
        )
    }

    init(
        ruuviPool: RuuviPool,
        ruuviStorage: RuuviStorage,
        ruuviReactor: RuuviReactor,
        foreground: any AdvertisementForegrounding,
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
        Task { [weak self] in
            guard let self else { return }
            if let sensors = try? await self.ruuviStorage.readAll() {
                self.ruuviTags = sensors
                self.rebuildRuuviTagIndex()
                self.pruneCachedState(keeping: self.tagIdentifierValues())
                self.restartObserving()
            }
        }
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
        ruuviTagsByLuid = RuuviTagAdvertisementDaemonCore.rebuildRuuviTagIndex(from: ruuviTags)
        widgetCache.syncSensors(ruuviTags) { [weak self] sensor in
            self?.sensorSettings(for: sensor)
        }
    }

    private func tagIdentifierValues() -> Set<String> {
        RuuviTagAdvertisementDaemonCore.tagIdentifierValues(from: ruuviTags)
    }

    private func pruneCachedState(keeping identifierValues: Set<String>) {
        stateQueue.sync {
            let prunedState = RuuviTagAdvertisementDaemonCore.pruneState(
                savedDate: savedDate,
                advertisementSequence: advertisementSequence,
                keeping: identifierValues
            )
            savedDate = prunedState.savedDate
            advertisementSequence = prunedState.advertisementSequence
        }
    }

    private func reloadSensorSettings() {
        sensorSettingsList.removeAll()
        Task { [weak self] in
            guard let self else { return }
            for ruuviTag in self.ruuviTags {
                do {
                    if let sensorSettings = try await self.ruuviStorage.readSensorSettings(ruuviTag) {
                        self.sensorSettingsList.append(sensorSettings)
                    }
                } catch {
                    continue
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
        RuuviTagAdvertisementDaemonCore.sensorSettings(
            for: ruuviTagSensor,
            in: sensorSettingsList
        )
    }

    private func snapshot(
        from ruuviTag: RuuviTag,
        source: RuuviTagSensorRecordSource
    ) -> WidgetSensorRecordSnapshot {
        RuuviTagAdvertisementDaemonCore.snapshot(from: ruuviTag, source: source)
    }

    @objc private func persist(wrapper: RuuviTagWrapper) {
        let uuid = wrapper.device.uuid
        guard wrapper.device.luid != nil else { return }
        if settings.appIsOnForeground {
            let shouldPersist = stateQueue.sync {
                RuuviTagAdvertisementDaemonCore.shouldPersist(
                    appIsOnForeground: true,
                    uuid: uuid,
                    measurementSequenceNumber: wrapper.device.measurementSequenceNumber,
                    lastSequenceNumber: advertisementSequence[uuid],
                    lastSavedDate: savedDate[uuid],
                    saveInterval: saveInterval
                )
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
                RuuviTagAdvertisementDaemonCore.shouldPersist(
                    appIsOnForeground: false,
                    uuid: uuid,
                    measurementSequenceNumber: wrapper.device.measurementSequenceNumber,
                    lastSequenceNumber: advertisementSequence[uuid],
                    lastSavedDate: savedDate[uuid],
                    saveInterval: saveInterval
                )
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
        let ruuviTagSensor = RuuviTagAdvertisementDaemonCore.matchingSensor(
            for: record,
            ruuviTagsByLuid: ruuviTagsByLuid,
            ruuviTags: ruuviTags
        )
        guard let ruuviTagSensor else { return }
        let settings = sensorSettings(for: ruuviTagSensor)
        widgetCache.upsert(
            sensor: ruuviTagSensor,
            record: snapshot(from: record, source: .advertisement),
            settings: settings
        )

        if RuuviTagAdvertisementDaemonCore.recordPlan(for: record) == .latestOnly {
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
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.ruuviPool.create(
                    record
                        .with(source: .advertisement)
                )
                self.createLatestRecord(with: record)
            } catch let error as RuuviPoolError {
                if case let RuuviPoolError.ruuviPersistence(persistenceError) = error {
                    switch persistenceError {
                    case .failedToFindRuuviTag:
                        self.removeCachedSensor(matching: record, fallbackUUID: uuid)
                        self.rebuildRuuviTagIndex()
                        self.pruneCachedState(keeping: self.tagIdentifierValues())
                        self.restartObserving()
                    default:
                        break
                    }
                }
                self.post(error: .ruuviPool(error))
            } catch {
                self.post(error: .ruuviPool(.ruuviPersistence(.grdb(error))))
            }
        }
    }

    private func removeCachedSensor(matching record: RuuviTag, fallbackUUID: String) {
        ruuviTags = RuuviTagAdvertisementDaemonCore.removeCachedSensor(
            matching: record,
            fallbackUUID: fallbackUUID,
            ruuviTagsByLuid: ruuviTagsByLuid,
            ruuviTags: ruuviTags
        )
    }

    private func createLatestRecord(with record: RuuviTag) {
        let ruuviTag = RuuviTagAdvertisementDaemonCore.matchingSensor(
            for: record,
            ruuviTagsByLuid: ruuviTagsByLuid,
            ruuviTags: ruuviTags
        )
        if let ruuviTag {
            Task { [weak self] in
                guard let self else { return }
                do {
                    let localRecord = try await self.ruuviStorage.readLatest(ruuviTag)
                    switch RuuviTagAdvertisementDaemonCore.latestRecordPlan(
                    for: record,
                    sensor: ruuviTag,
                    localRecord: localRecord
                    ) {
                    case let .createLast(latestRecord):
                        _ = try? await self.ruuviPool.createLast(latestRecord)
                    case let .updateLast(latestRecord):
                        _ = try? await self.ruuviPool.updateLast(latestRecord)
                    }
                } catch {
                    return
                }
            }
        }
    }
}

// swiftlint:enable file_length
