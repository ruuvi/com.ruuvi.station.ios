// swiftlint:disable file_length

import Foundation
import UIKit
import RuuviOntology
import RuuviReactor
import RuuviStorage
import RuuviService
import RuuviLocal
import RuuviDaemon
import RuuviPool
import RuuviLocalization
import RuuviCloud
#if canImport(WidgetKit)
    import WidgetKit
#endif
protocol RuuviTagDataServiceDelegate: AnyObject {
    func sensorDataService(
        _ service: RuuviTagDataService,
        didUpdateSnapshots snapshots: [RuuviTagCardSnapshot],
        withAnimation: Bool
    )
    func sensorDataService(
        _ service: RuuviTagDataService, didUpdateSnapshot snapshot: RuuviTagCardSnapshot,
        invalidateLayout: Bool
    )
    func sensorDataService(
        _ service: RuuviTagDataService,
        didAddNewSensor sensor: RuuviTagSensor,
        newOrder: [String]
    )
    func sensorDataService(
        _ service: RuuviTagDataService,
        didEncounterError error: Error
    )
}

extension RuuviTagDataServiceDelegate {
    func sensorDataService(
        _ service: RuuviTagDataService, didUpdateSnapshot snapshot: RuuviTagCardSnapshot,
        invalidateLayout: Bool = false
    ) {
        sensorDataService(
            service,
            didUpdateSnapshot: snapshot,
            invalidateLayout: invalidateLayout
        )
    }
}

class RuuviTagDataService {

    // MARK: - Dependencies
    private let ruuviReactor: RuuviReactor
    private let ruuviStorage: RuuviStorage
    private let measurementService: RuuviServiceMeasurement
    private let ruuviSensorPropertiesService: RuuviServiceSensorProperties
    private let settings: RuuviLocalSettings
    private let flags: RuuviLocalFlags
    private let ruuviPool: RuuviPool
    private let notificationCenter: NotificationCenter

    // MARK: - Properties
    weak var delegate: RuuviTagDataServiceDelegate?

    private var ruuviTags: [AnyRuuviTagSensor] = []
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var sensorSettingsList: [SensorSettings] = []
    private let sensorSettingsLock = NSLock()
    private func withSensorSettingsList<T>(_ block: ([SensorSettings]) -> T) -> T {
        sensorSettingsLock.lock()
        defer { sensorSettingsLock.unlock() }
        return block(sensorSettingsList)
    }
    private func updateSensorSettingsList(_ block: (inout [SensorSettings]) -> Void) {
        sensorSettingsLock.lock()
        defer { sensorSettingsLock.unlock() }
        block(&sensorSettingsList)
    }
    private func matchingSensorSettings(for sensor: RuuviTagSensor) -> SensorSettings? {
        withSensorSettingsList { list in
            list.first { candidate in
                if let sensorLuid = sensor.luid?.any,
                    let luid = candidate.luid?.any,
                    sensorLuid == luid
                {
                    return true
                }
                if let sensorMac = sensor.macId?.any,
                    let mac = candidate.macId?.any,
                    sensorMac == mac
                {
                    return true
                }
                return false
            }
        }
    }

    private var isObserving = false
    private var observationGeneration = UUID()
    private var recordTasks = [String: Task<Void, Never>]()
    private var imageTasks = [String: Task<Void, Never>]()
    private var subscriptionTasks = [String: Task<Void, Never>]()

    // MARK: - Observation Tokens
    private var ruuviTagToken: RuuviReactorToken?
    private var ruuviTagObserveLastRecordTokens = [RuuviReactorToken]()
    private var sensorSettingsTokens = [RuuviReactorToken]()
    private var backgroundToken: NSObjectProtocol?

    // MARK: - Initialization
    init(
        ruuviReactor: RuuviReactor,
        ruuviStorage: RuuviStorage,
        measurementService: RuuviServiceMeasurement,
        ruuviSensorPropertiesService: RuuviServiceSensorProperties,
        settings: RuuviLocalSettings,
        flags: RuuviLocalFlags,
        ruuviPool: RuuviPool,
        notificationCenter: NotificationCenter = .default
    ) {
        self.ruuviReactor = ruuviReactor
        self.ruuviStorage = ruuviStorage
        self.measurementService = measurementService
        self.ruuviSensorPropertiesService = ruuviSensorPropertiesService
        self.settings = settings
        self.flags = flags
        self.ruuviPool = ruuviPool
        self.notificationCenter = notificationCenter
        Self.setPreferredUnits(measurementService.units)
    }

    deinit {
        stopObservingSensors()
    }

    // MARK: - Public Interface
    func startObservingSensors() {
        guard !isObserving else { return }
        isObserving = true
        Self.setPreferredUnits(measurementService.units)
        observationGeneration = UUID()
        observeRuuviTags()
        observeBackgroundChanges()
        observeUnitChanges()
    }

    func stopObservingSensors() {
        isObserving = false
        observationGeneration = UUID()
        recordTasks.values.forEach { $0.cancel() }
        imageTasks.values.forEach { $0.cancel() }
        subscriptionTasks.values.forEach { $0.cancel() }
        recordTasks.removeAll()
        imageTasks.removeAll()
        subscriptionTasks.removeAll()
        ruuviTagToken?.invalidate()
        ruuviTagObserveLastRecordTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.forEach { $0.invalidate() }

        ruuviTagToken = nil
        ruuviTagObserveLastRecordTokens.removeAll()
        sensorSettingsTokens.removeAll()

        if let backgroundToken { notificationCenter.removeObserver(backgroundToken) }
        backgroundToken = nil
    }

    func updateSnapshot(for sensorId: String, with record: RuuviTagSensorRecord) {
        guard let snapshot = getSnapshot(for: sensorId), let sensor = getSensor(for: sensorId) else { return }
        updateSnapshot(snapshot, with: record, sensor: sensor)
    }

    func reorderSnapshots() {
        let orderedSnapshots = reorderSnapshots(
            snapshots,
            with: settings.dashboardSensorOrder
        )
        self.snapshots = orderedSnapshots
    }

    func reorderSnapshots(with orderedIds: [String]) {
        let reorderedSnapshots = reorderSnapshots(snapshots, with: orderedIds)
        snapshots = reorderedSnapshots
        if !settings.syncExtensiveChangesInProgress {
            delegate?
                .sensorDataService(
                    self,
                    didUpdateSnapshots: snapshots,
                    withAnimation: true
                )
        }
    }

    func snapshotSensorNameDidChange(
        to newName: String,
        for snapshot: RuuviTagCardSnapshot
    ) {
        guard let sensor = getSensor(for: snapshot.id) else { return }
        Task { @MainActor [properties = ruuviSensorPropertiesService] in
            do throws(RuuviServiceError) {
                let value = try await properties.set(name: newName, for: sensor)
                ({ _ in
                    #if canImport(WidgetKit)
                        UserDefaults(suiteName: AppGroupConstants.appGroupSuiteIdentifier)?.set(
                            true,
                            forKey: AppGroupConstants.forceRefreshWidgetKey
                        )
                        WidgetCenter.shared.reloadAllTimelines()
                    #endif
                })(value)
            } catch {
            }
        }
    }

    func getSnapshot(for sensorId: String) -> RuuviTagCardSnapshot? {
        return snapshots.first { $0.id == sensorId }
    }

    func getAllSnapshots() -> [RuuviTagCardSnapshot] {
        return snapshots
    }

    func getSensor(for sensorId: String) -> AnyRuuviTagSensor? {
        return ruuviTags.first { $0.id == sensorId }
    }

    func getAllSensors() -> [AnyRuuviTagSensor] {
        return ruuviTags
    }

    func getSensorSettings() -> [SensorSettings] {
        return withSensorSettingsList { $0 }
    }

    func getSensorSettings(for sensorId: String) -> SensorSettings? {
        return withSensorSettingsList { list in
            list.first(where: { settings in
                (settings.luid != nil && (settings.luid?.value == sensorId))
                    || (settings.macId != nil && (settings.macId?.any == sensorId.mac.any))
            })
        }
    }

    func refreshSubscriptionDataForSnapshots() {
        let currentSnapshots = snapshots
        for snapshot in currentSnapshots {
            guard let sensor = getSensor(for: snapshot.id) else { continue }
            syncMaxShareCount(for: snapshot, sensor: sensor)
        }
    }

    // MARK: - Background Loading
    func loadBackgroundsForCurrentSnapshots() {
        // This method can be called externally to force load backgrounds
        // Useful after extensive changes are complete
        for snapshot in snapshots {
            if let sensor = ruuviTags.first(where: { $0.id == snapshot.id }) {
                loadBackground(for: snapshot, sensor: sensor)
            }
        }
    }

    func loadBackground(for snapshot: RuuviTagCardSnapshot, sensor: AnyRuuviTagSensor) {
        guard isObserving else { return }
        imageTasks[sensor.id]?.cancel()
        let generation = observationGeneration
        imageTasks[sensor.id] = Task { @MainActor [weak self, weak snapshot, properties = ruuviSensorPropertiesService] in
            defer {
                if !Task.isCancelled, self?.observationGeneration == generation { self?.imageTasks[sensor.id] = nil }
            }
            do {
                let image = try await properties.getImage(for: sensor)
                guard let self, let snapshot, !Task.isCancelled,
                    self.isObserving, self.observationGeneration == generation,
                    self.getSnapshot(for: sensor.id) === snapshot,
                    !self.settings.syncExtensiveChangesInProgress else { return }
                if snapshot.updateBackgroundImage(image) {
                    self.delegate?.sensorDataService(self, didUpdateSnapshot: snapshot)
                }
            } catch {
                // Keep the current background when its replacement cannot be loaded.
            }
        }
    }

}

extension RuuviTagDataService: RuuviServiceMeasurementDelegate {
    func measurementServiceDidUpdateUnit() {
        Self.setPreferredUnits(measurementService.units)
        guard isObserving else { return }
        buildInitialSnapshots()
    }
}

// MARK: - Private Implementation
private extension RuuviTagDataService {

    func observeBackgroundChanges() {
        if let backgroundToken { notificationCenter.removeObserver(backgroundToken) }
        backgroundToken = notificationCenter.addObserver(
            forName: .BackgroundPersistenceDidChangeBackground,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, self.isObserving else { return }

            if let userInfo = notification.userInfo {
                let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier
                let macId = userInfo[BPDidChangeBackgroundKey.macId] as? MACIdentifier

                // Find the affected sensor
                var affectedSensor: AnyRuuviTagSensor?
                var affectedSnapshot: RuuviTagCardSnapshot?

                if let luid = luid {
                    affectedSensor = self.ruuviTags.first { $0.luid?.any == luid.any }
                } else if let macId = macId {
                    affectedSensor = self.ruuviTags.first { $0.macId?.any == macId.any }
                }

                if let sensor = affectedSensor {
                    affectedSnapshot = self.snapshots.first { $0.id == sensor.id }

                    // Reload the background for this sensor
                    if let snapshot = affectedSnapshot {
                        self.loadBackground(for: snapshot, sensor: sensor)
                    }
                }
            }
        }
    }

    func observeRuuviTags() {
        ruuviTagToken?.invalidate()
        let generation = observationGeneration
        ruuviTagToken = ruuviReactor.observe { [weak self] change in
            guard let self, self.isObserving, self.observationGeneration == generation else { return }

            switch change {
            case let .initial(ruuviTags):
                let reorderedTags = ruuviTags.reordered()
                self.ruuviTags = reorderedTags
                self.buildInitialSnapshots()
                self.observeSensorSettings()
                self.restartObservingRuuviTagLastRecords()

            case let .insert(sensor):
                if let existing = self.ruuviTags.firstIndex(where: { $0.id == sensor.id }) {
                    self.ruuviTags[existing] = sensor
                    self.updateSensorSnapshot(sensor: sensor)
                    return
                }
                self.ruuviTags.append(sensor.any)
                self.addSensorSnapshot(sensor: sensor.any)
                self.observeSensorSettings()
                self.restartObservingRuuviTagLastRecords()
                // TODO: Remove these calls after fixing the daemon observation
                self.notifyRestartAdvertisementDaemon()
                self.notifyRestartHeartBeatDaemon()

            case let .delete(sensor):
                self.recordTasks.removeValue(forKey: sensor.id)?.cancel()
                self.imageTasks.removeValue(forKey: sensor.id)?.cancel()
                self.subscriptionTasks.removeValue(forKey: sensor.id)?.cancel()
                self.updateSensorSettingsList { list in
                    list.removeAll {
                        ($0.luid != nil && $0.luid?.any == sensor.luid?.any)
                            || ($0.macId != nil && $0.macId?.any == sensor.macId?.any)
                    }
                }
                self.ruuviTags.removeAll { $0.id == sensor.id }
                self.snapshots.removeAll { $0.id == sensor.id }
                RuuviTagDataService.clearMeasurementDisplayPreference(for: sensor.id)
                if !self.settings.syncExtensiveChangesInProgress {
                    self.delegate?
                        .sensorDataService(
                            self,
                            didUpdateSnapshots: self.snapshots,
                            withAnimation: true
                        )
                }
                self.observeSensorSettings()
                self.restartObservingRuuviTagLastRecords()
                // TODO: Remove these calls after fixing the daemon observation
                self.notifyRestartAdvertisementDaemon()
                self.notifyRestartHeartBeatDaemon()

            case let .update(sensor):
                if let index = self.ruuviTags.firstIndex(where: {
                    ($0.macId != nil && $0.macId?.any == sensor.macId?.any)
                        || ($0.luid != nil && $0.luid?.any == sensor.luid?.any)
                }) {
                    self.ruuviTags[index] = sensor
                    self.updateSensorSnapshot(sensor: sensor)
                    self.restartObservingRuuviTagLastRecords()
                }

            case let .error(error):
                if !self.settings.syncExtensiveChangesInProgress {
                    self.delegate?.sensorDataService(self, didEncounterError: error)
                }
            }
        }
    }

    func observeUnitChanges() {
        measurementService.add(self)
    }

    func buildInitialSnapshots() {
        guard isObserving else { return }
        let previousSnapshots = snapshots
        let updatedSnapshots = ruuviTags.map { sensor in
            let snapshot = previousSnapshots.first { self.snapshot($0, matches: sensor) }
                ?? createSnapshot(from: sensor)
            updateMeasurementDisplayPreference(for: sensor, settings: matchingSensorSettings(for: sensor))
            populateSnapshot(snapshot, with: sensor)
            if let record = snapshot.latestRawRecord {
                let calibration = matchingSensorSettings(for: sensor)
                snapshot.updateFromRecord(record.with(sensorSettings: calibration), sensor: sensor, measurementService: measurementService,
                                          flags: flags, sensorSettings: calibration)
                _ = updateMeasurementVisibilityMetadata(for: snapshot, sensor: sensor, sensorSettings: calibration,
                    availableVariants: availableIndicatorVariants(from: record, sensor: sensor, snapshot: snapshot))
            }
            return snapshot
        }
        snapshots = reorderSnapshots(updatedSnapshots, with: settings.dashboardSensorOrder)
        if !settings.syncExtensiveChangesInProgress {
            delegate?.sensorDataService(self, didUpdateSnapshots: snapshots, withAnimation: false)
        }
        for snapshot in snapshots {
            guard let sensor = getSensor(for: snapshot.id) else { continue }
            if snapshot.displayData.background == nil { loadBackground(for: snapshot, sensor: sensor) }
            if snapshot.latestRawRecord == nil { loadLatestRecord(for: snapshot, sensor: sensor) }
        }
    }

    func loadLatestRecord(for snapshot: RuuviTagCardSnapshot, sensor: AnyRuuviTagSensor) {
        guard isObserving, recordTasks[sensor.id] == nil else { return }
        let generation = observationGeneration
        recordTasks[sensor.id] = Task { @MainActor [weak self, weak snapshot, storage = ruuviStorage] in
            defer {
                if !Task.isCancelled, self?.observationGeneration == generation { self?.recordTasks[sensor.id] = nil }
            }
            do {
                let record = try await storage.readLatest(sensor)
                guard let self, let snapshot, let record, !Task.isCancelled,
                    self.isObserving, self.observationGeneration == generation,
                    self.getSnapshot(for: sensor.id) === snapshot else { return }
                self.updateSnapshot(snapshot, with: record, sensor: sensor)
            } catch {
                // Live observations can still provide measurements when the stored read fails.
            }
        }
    }

    private func snapshot(
        _ snapshot: RuuviTagCardSnapshot,
        matches sensor: AnyRuuviTagSensor
    ) -> Bool {
        if let snapshotMac = snapshot.identifierData.mac,
            let sensorMac = sensor.macId,
            snapshotMac.any == sensorMac.any
        {
            return true
        }
        if let snapshotLuid = snapshot.identifierData.luid,
            let sensorLuid = sensor.luid,
            snapshotLuid.any == sensorLuid.any
        {
            return true
        }
        return snapshot.id == sensor.id
    }

    func createSnapshot(from sensor: AnyRuuviTagSensor) -> RuuviTagCardSnapshot {
        let snapshot = RuuviTagCardSnapshot.create(
            id: sensor.id,
            name: sensor.name,
            luid: sensor.luid,
            mac: sensor.macId,
            serviceUUID: sensor.serviceUUID,
            isCloud: sensor.isCloud,
            isOwner: sensor.isOwner,
            isConnectable: sensor.isConnectable,
            version: sensor.version
        )

        populateSnapshot(snapshot, with: sensor)
        return snapshot
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func addSensorSnapshot(sensor: AnyRuuviTagSensor) {
        let snapshot = createSnapshot(from: sensor)

        // Preserve existing background if available
        if let existing = snapshots.first(where: { $0.id == sensor.id }) {
            snapshot.displayData.background = existing.displayData.background
        }

        // For manual sorting, newly added sensor goes to the top
        if settings.dashboardSensorOrder.isEmpty {
            snapshots.append(snapshot)
            snapshots = reorderSnapshots(snapshots, with: [])
        } else {
            snapshots.insert(snapshot, at: 0)
        }

        // Keep ruuviTags array in sync with snapshots order
        var reorderedTags: [AnyRuuviTagSensor] = []
        for snap in snapshots {
            if let tag = ruuviTags.first(where: { $0.id == snap.id }) {
                reorderedTags.append(tag)
            }
        }
        // Add the new sensor if it wasn't already in ruuviTags
        if !reorderedTags.contains(where: { $0.id == sensor.id }) {
            // Find the position in snapshots
            if let snapshotIndex = snapshots.firstIndex(where: { $0.id == sensor.id }) {
                reorderedTags.insert(sensor, at: snapshotIndex)
            } else {
                reorderedTags.append(sensor)
            }
        }
        ruuviTags = reorderedTags

        // Load background for the new sensor
        loadBackground(for: snapshot, sensor: sensor)

        if !(settings.syncExtensiveChangesInProgress || settings.isSyncing) {
            let reorderdIds = snapshots.compactMap { $0.identifierData.mac?.value }
            self.delegate?.sensorDataService(
                self,
                didAddNewSensor: sensor,
                newOrder: reorderdIds
            )
        }

        if !self.settings.syncExtensiveChangesInProgress {
            delegate?
                .sensorDataService(
                    self,
                    didUpdateSnapshots: snapshots,
                    withAnimation: true
                )
        }

        loadLatestRecord(for: snapshot, sensor: sensor)
    }

    func updateSensorSnapshot(sensor: AnyRuuviTagSensor) {
        guard let snapshotIndex = snapshots.firstIndex(where: { $0.id == sensor.id }) else { return }

        let snapshot = snapshots[snapshotIndex]

        let generation = observationGeneration
        DispatchQueue.main.async { [weak self, weak snapshot] in
            guard let self, let snapshot, self.isObserving, self.observationGeneration == generation,
                self.getSnapshot(for: sensor.id) === snapshot else { return }
            let previousName = snapshot.displayData.name
            // Update basic sensor information
            let didUpdate = self.populateSnapshot(snapshot, with: sensor)
            let invalidateLayout = previousName != snapshot.displayData.name

            if didUpdate && !self.settings.syncExtensiveChangesInProgress {
                if invalidateLayout && self.settings.dashboardSensorOrder.isEmpty {
                    let previousOrder = self.snapshots.map(\.id)
                    let reorderedSnapshots = self.reorderSnapshots(
                        self.snapshots,
                        with: self.settings.dashboardSensorOrder
                    )
                    let reorderedOrder = reorderedSnapshots.map(\.id)

                    if previousOrder != reorderedOrder {
                        self.snapshots = reorderedSnapshots
                        self.ruuviTags = reorderedSnapshots.compactMap { snapshot in
                            self.ruuviTags.first { $0.id == snapshot.id }
                        }
                        self.delegate?
                            .sensorDataService(
                                self,
                                didUpdateSnapshots: self.snapshots,
                                withAnimation: true
                            )
                    } else {
                        self.delegate?
                            .sensorDataService(
                                self,
                                didUpdateSnapshot: snapshot,
                                invalidateLayout: invalidateLayout
                            )
                    }
                } else {
                    self.delegate?
                        .sensorDataService(
                            self,
                            didUpdateSnapshot: snapshot,
                            invalidateLayout: invalidateLayout
                        )
                }
            }
        }
    }

    func observeSensorSettings() {
        sensorSettingsTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()

        let generation = observationGeneration
        for sensor in ruuviTags {
            let sensorId = sensor.id
            let macId = sensor.macId
            let luid = sensor.luid
            sensorSettingsTokens.append(
                ruuviReactor.observe(sensor) { [weak self] change in
                    guard let self, self.isObserving, self.observationGeneration == generation else { return }
                    self.processSensorSettingsChange(
                        change,
                        id: sensorId,
                        macId: macId,
                        luid: luid
                    )
                }
            )
        }
    }

    func processSensorSettingsChange(
        _ change: RuuviReactorChange<SensorSettings>,
        id: String,
        macId: MACIdentifier?,
        luid: LocalIdentifier?
    ) {
        if case let .error(error) = change {
            if !settings.syncExtensiveChangesInProgress {
                delegate?.sensorDataService(self, didEncounterError: error)
            }
            return
        }

        guard let sensor = currentSensor(id: id, macId: macId, luid: luid) else { return }

        switch change {
        case let .insert(sensorSettings):
            updateSensorSettingsList { $0.append(sensorSettings) }
            applySensorSettings(sensorSettings, to: sensor)
        case let .update(sensorSettings):
            updateSensorSettings(sensorSettings, for: sensor)
        case let .delete(sensorSettings):
            updateSensorSettingsList { list in
                if let index = list.firstIndex(where: { $0.id == sensorSettings.id }) {
                    list.remove(at: index)
                }
            }
            applySensorSettings(nil, to: sensor)
        case let .initial(initialSettings):
            initialSettings.forEach { updateSensorSettings($0, for: sensor) }
        case .error:
            break
        }
    }

    func currentSensor(
        id: String,
        macId: MACIdentifier?,
        luid: LocalIdentifier?
    ) -> AnyRuuviTagSensor? {
        if let sensor = ruuviTags.first(where: { $0.id == id }) {
            return sensor
        }
        if let macId,
            let sensor = ruuviTags.first(where: { $0.macId?.any == macId.any })
        {
            return sensor
        }
        if let luid {
            return ruuviTags.first { $0.luid?.any == luid.any }
        }
        return nil
    }

    func updateSensorSettings(_ sensorSettings: SensorSettings, for sensor: AnyRuuviTagSensor) {
        updateSensorSettingsList { list in
            if let index = list.firstIndex(where: { $0.id == sensorSettings.id }) {
                list[index] = sensorSettings
            } else {
                list.append(sensorSettings)
            }
        }

        applySensorSettings(sensorSettings, to: sensor)
    }

    func applySensorSettings(_ sensorSettings: SensorSettings?, to sensor: AnyRuuviTagSensor) {
        updateMeasurementDisplayPreference(for: sensor, settings: sensorSettings)

        guard let snapshot = snapshots.first(where: { $0.id == sensor.id }) else { return }

        if let record = snapshot.latestRawRecord {
            updateSnapshot(snapshot, with: record, sensor: sensor)
        } else {
            loadLatestRecord(for: snapshot, sensor: sensor)
        }
    }

    // swiftlint:disable:next function_body_length
    private func updateMeasurementDisplayPreference(
        for sensor: AnyRuuviTagSensor,
        settings: SensorSettings?
    ) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateMeasurementDisplayPreference(
                    for: sensor,
                    settings: settings
                )
            }
            return
        }

        guard let codes = settings?.displayOrder, !codes.isEmpty else {
            RuuviTagDataService.clearMeasurementDisplayPreference(for: sensor.id)
            if let snapshot = snapshots.first(where: { $0.id == sensor.id }) {
                let didChange = updateMeasurementVisibilityMetadata(
                    for: snapshot,
                    sensor: sensor,
                    sensorSettings: settings,
                    availableVariants: snapshot.displayData.measurementVisibility?.availableVariants
                )
                let visibility = snapshot.displayData.measurementVisibility
                let gridMatches = indicatorGridMatchesVisibility(
                    snapshot: snapshot,
                    visibility: visibility
                )
                let shouldRebuildGrid = didChange || !gridMatches
                if shouldRebuildGrid {
                    rebuildIndicatorGrid(for: snapshot, sensor: sensor, sensorSettings: settings)
                }
                DispatchQueue.main.async { [weak self, weak snapshot] in
                    guard let self, let snapshot, self.getSnapshot(for: sensor.id) === snapshot else { return }
                    if shouldRebuildGrid {
                        self.publishSnapshotUpdate(snapshot, force: true)
                    } else {
                        self.publishSnapshotUpdate(snapshot)
                    }
                }
            }
            return
        }

        let preference = RuuviTagDataService.MeasurementDisplayPreference(
            defaultDisplayOrder: settings?.defaultDisplayOrder ?? true,
            displayOrderCodes: codes
        )

        RuuviTagDataService.setMeasurementDisplayPreference(preference, for: sensor.id)

        if let snapshot = snapshots.first(where: { $0.id == sensor.id }) {
            let didChange = updateMeasurementVisibilityMetadata(
                for: snapshot,
                sensor: sensor,
                sensorSettings: settings,
                availableVariants: snapshot.displayData.measurementVisibility?.availableVariants
            )
            let visibility = snapshot.displayData.measurementVisibility
            let gridMatches = indicatorGridMatchesVisibility(
                snapshot: snapshot,
                visibility: visibility
            )
            let shouldRebuildGrid = didChange || !gridMatches
            if shouldRebuildGrid {
                rebuildIndicatorGrid(for: snapshot, sensor: sensor, sensorSettings: settings)
            }

            DispatchQueue.main.async { [weak self, weak snapshot] in
                guard let self, let snapshot, self.getSnapshot(for: sensor.id) === snapshot else { return }
                if shouldRebuildGrid {
                    self.publishSnapshotUpdate(snapshot, force: true)
                } else {
                    self.publishSnapshotUpdate(snapshot)
                }
            }
        }
    }

    func restartObservingRuuviTagLastRecords() {
        ruuviTagObserveLastRecordTokens.forEach { $0.invalidate() }
        ruuviTagObserveLastRecordTokens.removeAll()
        let generation = observationGeneration
        for sensor in ruuviTags {
            let token = ruuviReactor.observeLatest(sensor) { [weak self] change in
                guard let self, self.isObserving, self.observationGeneration == generation,
                    let snapshot = self.getSnapshot(for: sensor.id) else { return }
                let record: RuuviTagSensorRecord?
                switch change {
                case .initial(let records): record = records.compactMap { $0 }.max { $0.date < $1.date }
                case .insert(let value), .update(let value): record = value
                case .delete, .error: return
                }
                if let record { self.updateSnapshot(snapshot, with: record, sensor: sensor) }
            }
            ruuviTagObserveLastRecordTokens.append(token)
        }
    }

    func reorderSnapshots(
        _ snapshots: [RuuviTagCardSnapshot],
        with orderedIds: [String]
    ) -> [RuuviTagCardSnapshot] {
        guard !orderedIds.isEmpty else {
            // Alphabetical sorting
            return snapshots.sorted { first, second in
                first.displayData.name.localizedStandardCompare(
                    second.displayData.name
                ) == .orderedAscending
            }
        }

        // Manual sorting based on MAC IDs
        return snapshots.sorted { first, second in
            guard let firstMacId = first.identifierData.mac?.value,
                let secondMacId = second.identifierData.mac?.value
            else { return false }

            let firstIndex = orderedIds.firstIndex(of: firstMacId) ?? Int.max
            let secondIndex = orderedIds.firstIndex(of: secondMacId) ?? Int.max
            return firstIndex < secondIndex
        }
    }

    func notifyRestartAdvertisementDaemon() {
        notificationCenter
            .post(
                name: .RuuviTagAdvertisementDaemonShouldRestart,
                object: nil,
                userInfo: nil
            )
    }

    func notifyRestartHeartBeatDaemon() {
        notificationCenter
            .post(
                name: .RuuviTagHeartBeatDaemonShouldRestart,
                object: nil,
                userInfo: nil
            )
    }

    // MARK: - Snapshot helpers
    @discardableResult
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func populateSnapshot(
        _ snapshot: RuuviTagCardSnapshot,
        with sensor: AnyRuuviTagSensor
    ) -> Bool {
        var didChange = false

        var updatedDisplay = snapshot.displayData
        if updatedDisplay.name != sensor.name {
            updatedDisplay.name = sensor.name
        }
        if updatedDisplay.version != sensor.version {
            updatedDisplay.version = sensor.version
        }
        let firmware = sensor.displayFirmwareVersion ?? sensor.firmwareVersion
        if updatedDisplay.firmwareVersion != firmware {
            updatedDisplay.firmwareVersion = firmware
        }
        if updatedDisplay != snapshot.displayData {
            snapshot.displayData = updatedDisplay
            didChange = true
        }

        var updatedConnectionData = snapshot.connectionData
        if updatedConnectionData.isConnectable != sensor.isConnectable {
            updatedConnectionData.isConnectable = sensor.isConnectable
        }
        if updatedConnectionData != snapshot.connectionData {
            snapshot.connectionData = updatedConnectionData
            didChange = true
        }

        if snapshot.updateMetadata(
            isCloud: sensor.isCloud,
            isOwner: sensor.isOwner,
            isConnectable: sensor.isConnectable,
            canShareTag: (sensor.isOwner && sensor.isClaimed) || sensor.canShare
        ) {
            didChange = true
        }

        var updatedOwnership = snapshot.ownership
        let ownerName = sensor.owner?.lowercased() ?? RuuviLocalization.TagSettings.General.Owner.none
        if updatedOwnership.ownerName != ownerName {
            updatedOwnership.ownerName = ownerName
        }
        if updatedOwnership.ownersPlan != sensor.ownersPlan {
            updatedOwnership.ownersPlan = sensor.ownersPlan
        }
        if updatedOwnership.sharedTo != sensor.sharedTo {
            updatedOwnership.sharedTo = sensor.sharedTo
        }
        if updatedOwnership.sharedToPending != sensor.sharedToPending {
            updatedOwnership.sharedToPending = sensor.sharedToPending
        }
        let canBeClaimed = !sensor.isClaimed && sensor.macId != nil && (sensor.owner == nil || sensor.isOwner)
        if updatedOwnership.canClaimTag != canBeClaimed {
            updatedOwnership.canClaimTag = canBeClaimed
        }
        let claimed = !canBeClaimed
        if updatedOwnership.isClaimedTag != claimed {
            updatedOwnership.isClaimedTag = claimed
        }
        let proPlan = isProPlan(sensor.ownersPlan)
        if updatedOwnership.isOwnersPlanProPlus != proPlan {
            updatedOwnership.isOwnersPlanProPlus = proPlan
        }
        if updatedOwnership != snapshot.ownership {
            snapshot.ownership = updatedOwnership
            didChange = true
        }
        // Ensure we keep max share limit in sync for share UI summaries.
        syncMaxShareCount(for: snapshot, sensor: sensor)

        var updatedCapabilities = snapshot.capabilities
        let showConnectionControls = shouldShowConnectionControls(for: sensor)
        if updatedCapabilities.showKeepConnection != showConnectionControls {
            updatedCapabilities.showKeepConnection = showConnectionControls
        }
        if updatedCapabilities.showBatteryStatus != showConnectionControls {
            updatedCapabilities.showBatteryStatus = showConnectionControls
        }
        let hideStatusLabel = !settings.showSwitchStatusLabel
        if updatedCapabilities.hideSwitchStatusLabel != hideStatusLabel {
            updatedCapabilities.hideSwitchStatusLabel = hideStatusLabel
        }
        if updatedCapabilities.isCloudAlertsAvailable != sensor.isCloud {
            updatedCapabilities.isCloudAlertsAvailable = sensor.isCloud
        }
        let cloudConnectionAvailable = sensor.isCloud && updatedOwnership.isOwnersPlanProPlus
        if updatedCapabilities.isCloudConnectionAlertsAvailable != cloudConnectionAvailable {
            updatedCapabilities.isCloudConnectionAlertsAvailable = cloudConnectionAvailable
        }
        let alertsEnabled =
            sensor.isCloud || snapshot.connectionData.isConnected || sensor.serviceUUID != nil
        if updatedCapabilities.isAlertsEnabled != alertsEnabled {
            updatedCapabilities.isAlertsEnabled = alertsEnabled
        }
        if updatedCapabilities != snapshot.capabilities {
            snapshot.capabilities = updatedCapabilities
            didChange = true
        }

        let sensorSettings = matchingSensorSettings(for: sensor)

        if let sensorSettings {
            var updatedCalibration = snapshot.calibration
            let tempOffset =
                measurementService
                .temperatureOffsetCorrectionString(for: sensorSettings.temperatureOffset ?? 0)
            if updatedCalibration.temperatureOffset != tempOffset {
                updatedCalibration.temperatureOffset = tempOffset
            }
            let humidityOffset =
                measurementService
                .humidityOffsetCorrectionString(for: sensorSettings.humidityOffset ?? 0)
            if updatedCalibration.humidityOffset != humidityOffset {
                updatedCalibration.humidityOffset = humidityOffset
            }
            let pressureOffset =
                measurementService
                .pressureOffsetCorrectionString(for: sensorSettings.pressureOffset ?? 0)
            if updatedCalibration.pressureOffset != pressureOffset {
                updatedCalibration.pressureOffset = pressureOffset
            }

            if updatedCalibration != snapshot.calibration {
                snapshot.calibration = updatedCalibration
                didChange = true
            }
        } else {
            var updatedCalibration = snapshot.calibration
            let zeroTemp = measurementService.temperatureOffsetCorrectionString(for: 0)
            if updatedCalibration.temperatureOffset != zeroTemp {
                updatedCalibration.temperatureOffset = zeroTemp
            }
            let zeroHumidity = measurementService.humidityOffsetCorrectionString(for: 0)
            if updatedCalibration.humidityOffset != zeroHumidity {
                updatedCalibration.humidityOffset = zeroHumidity
            }
            let zeroPressure = measurementService.pressureOffsetCorrectionString(for: 0)
            if updatedCalibration.pressureOffset != zeroPressure {
                updatedCalibration.pressureOffset = zeroPressure
            }

            if updatedCalibration != snapshot.calibration {
                snapshot.calibration = updatedCalibration
                didChange = true
            }
        }

        if updateMeasurementVisibilityMetadata(
            for: snapshot,
            sensor: sensor,
            sensorSettings: sensorSettings,
            availableVariants: snapshot.displayData.measurementVisibility?.availableVariants
        ) {
            didChange = true
        }

        return didChange
    }

    private func shouldShowConnectionControls(for sensor: AnyRuuviTagSensor) -> Bool {
        let firmware = RuuviDataFormat.dataFormat(from: sensor.version)
        return !(firmware == .e1 || firmware == .v6)
    }

    private func isProPlan(_ plan: String?) -> Bool {
        guard let plan = plan?.lowercased() else { return false }
        return plan != "basic" && plan != "free"
    }

    private func publishSnapshotUpdate(
        _ snapshot: RuuviTagCardSnapshot,
        invalidateLayout: Bool = false,
        force: Bool = false
    ) {
        guard isObserving, force || !settings.syncExtensiveChangesInProgress else { return }
        let notify = {
            self.delegate?.sensorDataService(
                self,
                didUpdateSnapshot: snapshot,
                invalidateLayout: invalidateLayout
            )
        }
        if Thread.isMainThread {
            notify()
        } else {
            DispatchQueue.main.async {
                notify()
            }
        }
    }

    @discardableResult
    private func updateMeasurementVisibilityMetadata(
        for snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor?,
        sensorSettings: SensorSettings?,
        availableVariants: [MeasurementDisplayVariant]? = nil
    ) -> Bool {
        let preference: MeasurementDisplayPreference?
        if let sensor {
            preference = Self.measurementDisplayPreference(for: sensor.id)
        } else {
            preference = Self.measurementDisplayPreference(for: snapshot.id)
        }

        let usesDefaultOrder: Bool
        if let preference {
            usesDefaultOrder = preference.defaultDisplayOrder
        } else if let explicitDefault = sensorSettings?.defaultDisplayOrder {
            usesDefaultOrder = explicitDefault
        } else if let displayOrder = sensorSettings?.displayOrder, !displayOrder.isEmpty {
            usesDefaultOrder = false
        } else {
            usesDefaultOrder = true
        }

        let displayProfile: MeasurementDisplayProfile
        if let sensor {
            displayProfile = RuuviTagDataService.measurementDisplayProfile(for: sensor)
        } else {
            displayProfile = RuuviTagDataService.measurementDisplayProfile(for: snapshot)
        }

        let profileAvailable = displayProfile.entriesSupporting(.indicator).map(\.variant)
        let availableSource =
            availableVariants
            ?? snapshot.displayData.measurementVisibility?.availableVariants
            ?? profileAvailable
        let orderedAvailableBase = profileAvailable.filter { availableSource.contains($0) }
        let remainingAvailable = availableSource.filter { candidate in
            !orderedAvailableBase.contains(candidate)
        }
        var resolvedAvailable = orderedAvailableBase + remainingAvailable
        if resolvedAvailable.isEmpty {
            resolvedAvailable = profileAvailable
        }

        let visibleOrdered = displayProfile.orderedVisibleVariants(for: .indicator)
        var visibleIntersection = visibleOrdered.filter { resolvedAvailable.contains($0) }
        if visibleIntersection.isEmpty {
            visibleIntersection = resolvedAvailable.filter { visibleOrdered.contains($0) }
        }
        let hiddenVariants = resolvedAvailable.filter { !visibleIntersection.contains($0) }

        let visibility = RuuviTagCardSnapshotMeasurementVisibility(
            usesDefaultOrder: usesDefaultOrder,
            availableVariants: resolvedAvailable,
            visibleVariants: visibleIntersection,
            hiddenVariants: hiddenVariants
        )

        return snapshot.updateMeasurementVisibility(visibility)
    }

    private func syncMaxShareCount(for snapshot: RuuviTagCardSnapshot, sensor: AnyRuuviTagSensor) {
        guard isObserving else { return }
        subscriptionTasks[sensor.id]?.cancel()
        let generation = observationGeneration
        subscriptionTasks[sensor.id] = Task { @MainActor [weak self, weak snapshot, pool = ruuviPool] in
            defer {
                if !Task.isCancelled, self?.observationGeneration == generation { self?.subscriptionTasks[sensor.id] = nil }
            }
            do {
                let subscription = try await pool.readSensorSubscriptionSettings(sensor)
                guard let self, let snapshot, !Task.isCancelled,
                    self.isObserving, self.observationGeneration == generation,
                    self.getSnapshot(for: sensor.id) === snapshot else { return }
                let limit = subscription?.maxSharesPerSensor
                guard snapshot.ownership.maxShareCount != limit else { return }
                snapshot.ownership.maxShareCount = limit
                if !self.settings.syncExtensiveChangesInProgress {
                    self.delegate?.sensorDataService(self, didUpdateSnapshot: snapshot)
                }
            } catch {
                // Keep the last known limit on transient storage errors.
            }
        }
    }

    private func updateSnapshot(_ snapshot: RuuviTagCardSnapshot, with record: RuuviTagSensorRecord,
                                sensor: AnyRuuviTagSensor) {
        let generation = observationGeneration
        DispatchQueue.main.async { [weak self, weak snapshot] in
            guard let self, let snapshot, self.isObserving, self.observationGeneration == generation,
                self.getSnapshot(for: sensor.id) === snapshot,
                let currentSensor = self.currentSensor(id: sensor.id, macId: sensor.macId, luid: sensor.luid)
            else { return }
            if let previousDate = snapshot.lastUpdated, record.date < previousDate { return }
            let calibration = self.matchingSensorSettings(for: currentSensor)
            let enriched = record.with(sensorSettings: calibration)
            let didUpdate = snapshot.updateFromRecord(enriched, sensor: currentSensor,
                measurementService: self.measurementService, flags: self.flags, sensorSettings: calibration)
            let available = self.availableIndicatorVariants(from: enriched, sensor: currentSensor, snapshot: snapshot)
            let visibilityChanged = self.updateMeasurementVisibilityMetadata(for: snapshot, sensor: currentSensor,
                sensorSettings: calibration, availableVariants: available)
            if visibilityChanged {
                self.rebuildIndicatorGrid(for: snapshot, sensor: currentSensor, sensorSettings: calibration)
                self.publishSnapshotUpdate(snapshot, force: true)
            } else if didUpdate {
                self.publishSnapshotUpdate(snapshot)
            }
        }
    }

    private func availableIndicatorVariants(
        from record: RuuviTagSensorRecord,
        sensor: AnyRuuviTagSensor,
        snapshot: RuuviTagCardSnapshot
    ) -> [MeasurementDisplayVariant] {
        let baseProfile = RuuviTagDataService.defaultMeasurementDisplayProfile(for: sensor)
        let entries = baseProfile.entriesSupporting(.indicator)

        var seen = Set<MeasurementDisplayVariant>()
        var variants: [MeasurementDisplayVariant] = []

        for entry in entries {
            guard let extractor = MeasurementExtractorFactory.extractor(for: entry.variant.type),
                // swiftlint:disable:next unused_optional_binding
                let _ = extractor.extract(
                    from: record,
                    measurementService: measurementService,
                    flags: flags,
                    variant: entry.variant,
                    snapshot: snapshot
                )
            else {
                continue
            }

            if seen.insert(entry.variant).inserted {
                variants.append(entry.variant)
            }
        }

        return variants
    }

    private func rebuildIndicatorGrid(
        for snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor?,
        sensorSettings: SensorSettings?
    ) {
        guard
            let baseSensor = sensor
                ?? ruuviTags.first(where: {
                    $0.id == snapshot.id
                })
        else { return }
        guard let latestRecord = snapshot.latestRawRecord else { return }
        let enrichedRecord = sensorSettings != nil ? latestRecord.with(sensorSettings: sensorSettings) : latestRecord

        let newGrid = RuuviTagCardSnapshotDataBuilder.createIndicatorGrid(
            from: enrichedRecord,
            sensor: baseSensor,
            measurementService: measurementService,
            flags: flags,
            snapshot: snapshot
        )
        snapshot.displayData.indicatorGrid = newGrid
        snapshot.displayData.hasNoData = newGrid == nil
    }

    private func indicatorGridMatchesVisibility(
        snapshot: RuuviTagCardSnapshot,
        visibility: RuuviTagCardSnapshotMeasurementVisibility?
    ) -> Bool {
        guard let visibility else { return true }
        let desired = visibility.visibleVariants
        let current = snapshot.displayData.indicatorGrid?.indicators.map(\.variant) ?? []
        if desired.isEmpty {
            return current.isEmpty
        }
        return desired == current
    }
}

// MARK: - Measurement Display Helpers

extension RuuviTagDataService {
    private static var measurementDisplayOverrides: [String: MeasurementDisplayProfile] = [:]
    private static var measurementDisplayPreferenceOverrides: [String: MeasurementDisplayPreference] = [:]
    private static let measurementDisplayOverrideQueue = DispatchQueue(
        label: "com.ruuvi.measurement.display.override.queue",
        attributes: .concurrent
    )
    private static var preferredUnits = RuuviServiceMeasurementSettingsUnit(
        temperatureUnit: .defaultFromSystemPreferences(),
        humidityUnit: .percent,
        pressureUnit: .hectopascals
    )

    static func measurementDisplayProfile(
        for sensor: RuuviTagSensor,
        useDefaultOrder: Bool = false
    ) -> MeasurementDisplayProfile {
        let preference = useDefaultOrder ? nil : measurementDisplayPreference(for: sensor.id)
        let baseProfile = measurementDisplayOverride(for: sensor.id) ?? defaultMeasurementDisplayProfile(for: sensor)
        let profileWithPreference = applyMeasurementPreference(
            preference: preference,
            to: baseProfile
        )
        return applyPreferredUnitsIfNeeded(
            profileWithPreference,
            preference: preference
        )
    }

    static func measurementDisplayProfile(
        for snapshot: RuuviTagCardSnapshot,
        useDefaultOrder: Bool = false
    ) -> MeasurementDisplayProfile {
        let preference = useDefaultOrder ? nil : measurementDisplayPreference(for: snapshot.id)
        let baseProfile =
            measurementDisplayOverride(for: snapshot.id) ?? defaultMeasurementDisplayProfile(for: snapshot)
        let profileWithPreference = applyMeasurementPreference(
            preference: preference,
            to: baseProfile
        )
        return applyPreferredUnitsIfNeeded(
            profileWithPreference,
            preference: preference
        )
    }

    static func alertMeasurementVariants(
        for sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?
    ) -> [MeasurementDisplayVariant] {
        let profile = measurementDisplayProfile(for: sensor)
        let variants = profile.orderedVisibleVariants(for: .alert)
        return normalizedAlertVariants(
            variants,
            profile: profile,
            preferredTemperature: measurementService?.units.temperatureUnit,
            preferredPressure: measurementService?.units.pressureUnit
        )
    }

    static func alertMeasurementVariants(
        for snapshot: RuuviTagCardSnapshot,
        measurementService: RuuviServiceMeasurement?
    ) -> [MeasurementDisplayVariant] {
        let profile = measurementDisplayProfile(for: snapshot)
        let variants = profile.orderedVisibleVariants(for: .alert)
        return normalizedAlertVariants(
            variants,
            profile: profile,
            preferredTemperature: measurementService?.units.temperatureUnit,
            preferredPressure: measurementService?.units.pressureUnit
        )
    }

    static func defaultMeasurementDisplayProfile() -> MeasurementDisplayProfile {
        measurementDisplayTemplateAir
    }

    static func setMeasurementDisplayOverride(
        _ profile: MeasurementDisplayProfile?,
        for sensorId: String
    ) {
        measurementDisplayOverrideQueue.async(flags: .barrier) {
            if let profile {
                measurementDisplayOverrides[sensorId] = profile
            } else {
                measurementDisplayOverrides.removeValue(forKey: sensorId)
            }
        }
    }

    static func clearMeasurementDisplayOverride(for sensorId: String) {
        setMeasurementDisplayOverride(nil, for: sensorId)
    }

    static func clearAllMeasurementDisplayOverrides() {
        measurementDisplayOverrideQueue.async(flags: .barrier) {
            measurementDisplayOverrides.removeAll()
            measurementDisplayPreferenceOverrides.removeAll()
        }
    }

    static func setPreferredUnits(_ units: RuuviServiceMeasurementSettingsUnit) {
        measurementDisplayOverrideQueue.async(flags: .barrier) {
            preferredUnits = units
        }
    }

    private static func preferredUnitsSnapshot() -> RuuviServiceMeasurementSettingsUnit {
        measurementDisplayOverrideQueue.sync {
            preferredUnits
        }
    }

    private static func measurementDisplayOverride(
        for sensorId: String
    ) -> MeasurementDisplayProfile? {
        var override: MeasurementDisplayProfile?
        measurementDisplayOverrideQueue.sync {
            override = measurementDisplayOverrides[sensorId]
        }
        return override
    }

    static func setMeasurementDisplayPreference(
        _ preference: MeasurementDisplayPreference?,
        for sensorId: String
    ) {
        // Example:
        // RuuviTagDataService.setMeasurementDisplayPreference(
        //     .init(
        //         defaultDisplayOrder: false,
        //         displayOrderCodes: [
        //             "TEMPERATURE_C",
        //             "HUMIDITY_0",
        //             "ACCELERATION_GX",
        //             "ACCELERATION_GY",
        //             "ACCELERATION_GZ",
        //             "SIGNAL_DBM",
        //         ]
        //     ),
        //     for: sensor.id
        // )
        measurementDisplayOverrideQueue.async(flags: .barrier) {
            if let preference {
                measurementDisplayPreferenceOverrides[sensorId] = preference
            } else {
                measurementDisplayPreferenceOverrides.removeValue(forKey: sensorId)
            }
        }
    }

    static func clearMeasurementDisplayPreference(for sensorId: String) {
        setMeasurementDisplayPreference(nil, for: sensorId)
    }

    private static func measurementDisplayPreference(
        for sensorId: String
    ) -> MeasurementDisplayPreference? {
        var preference: MeasurementDisplayPreference?
        measurementDisplayOverrideQueue.sync {
            preference = measurementDisplayPreferenceOverrides[sensorId]
        }
        return preference
    }

    static func defaultMeasurementDisplayProfile(
        for sensor: RuuviTagSensor
    ) -> MeasurementDisplayProfile {
        let format = RuuviDataFormat.dataFormat(from: sensor.version)
        return defaultMeasurementDisplayProfile(for: format)
    }

    static func defaultMeasurementDisplayProfile(
        for snapshot: RuuviTagCardSnapshot
    ) -> MeasurementDisplayProfile {
        let format = RuuviDataFormat.dataFormat(from: snapshot.displayData.version.bound)
        return defaultMeasurementDisplayProfile(for: format)
    }

    private static func defaultMeasurementDisplayProfile(
        for format: RuuviDataFormat
    ) -> MeasurementDisplayProfile {
        switch format {
        case .e1, .v6:
            return measurementDisplayTemplateAir
        default:
            return measurementDisplayTemplateTag
        }
    }

    private static let measurementDisplayTemplateAir = MeasurementDisplayProfile(
        entries: makeEntries(for: airMeasurementOrder)
    )

    private static let measurementDisplayTemplateTag = MeasurementDisplayProfile(
        entries: makeEntries(for: tagMeasurementOrder)
    )

    private static let airMeasurementOrder: [MeasurementType] = MeasurementDisplayDefaults.airMeasurementOrder

    private static let tagMeasurementOrder: [MeasurementType] = MeasurementDisplayDefaults.tagMeasurementOrder

    /// Declarative baseline for a measurement's default visibility + contexts.
    private struct MeasurementDisplayConfiguration {
        let contexts: MeasurementDisplayContext
        let isVisible: Bool
    }

    /// User-defined ordering data synced with preferences/cloud.
    struct MeasurementDisplayPreference {
        let defaultDisplayOrder: Bool
        let displayOrderCodes: [String]

        public init(
            defaultDisplayOrder: Bool = true,
            displayOrderCodes: [String]
        ) {
            self.defaultDisplayOrder = defaultDisplayOrder
            self.displayOrderCodes = displayOrderCodes
        }
    }

    // Measurements that need explicit defaults differing from the "visible everywhere" baseline.
    // Example: to make a metric hidden but available later, set contexts to the supported set and `isVisible` to false.
    // Example: to restrict a metric to Alerts only, set `contexts: [.alert]`.
    private static let measurementVariantOverrides: [MeasurementDisplayVariant: MeasurementDisplayConfiguration] = [
        MeasurementDisplayVariant(type: .pm10): MeasurementDisplayConfiguration(
            contexts: [.all],
            isVisible: false
        ),
        MeasurementDisplayVariant(type: .pm40): MeasurementDisplayConfiguration(
            contexts: [.all],
            isVisible: false
        ),
        MeasurementDisplayVariant(type: .pm100): MeasurementDisplayConfiguration(
            contexts: [.all],
            isVisible: false
        ),
        MeasurementDisplayVariant(type: .measurementSequenceNumber): MeasurementDisplayConfiguration(
            contexts: [.indicator],
            isVisible: false
        ),
        MeasurementDisplayVariant(type: .soundAverage): MeasurementDisplayConfiguration(
            contexts: [.all],
            isVisible: false
        ),
        MeasurementDisplayVariant(type: .soundPeak): MeasurementDisplayConfiguration(
            contexts: [.all],
            isVisible: false
        ),
        MeasurementDisplayVariant(type: .movementCounter): MeasurementDisplayConfiguration(
            contexts: [.indicator, .alert],
            isVisible: true
        ),
        MeasurementDisplayVariant(type: .voltage): MeasurementDisplayConfiguration(
            contexts: [.indicator, .graph, .alert],
            isVisible: false
        ),
        MeasurementDisplayVariant(type: .rssi): MeasurementDisplayConfiguration(
            contexts: [.indicator, .graph, .alert],
            isVisible: false
        ),
        MeasurementDisplayVariant(type: .accelerationX): MeasurementDisplayConfiguration(
            contexts: [.indicator, .graph],
            isVisible: false
        ),
        MeasurementDisplayVariant(type: .accelerationY): MeasurementDisplayConfiguration(
            contexts: [.indicator, .graph],
            isVisible: false
        ),
        MeasurementDisplayVariant(type: .accelerationZ): MeasurementDisplayConfiguration(
            contexts: [.indicator, .graph],
            isVisible: false
        ),
    ]

    static func measurementCode(
        for variant: MeasurementDisplayVariant
    ) -> String? {
        variant.cloudVisibilityCode?.rawValue
    }

    static func measurementVariant(
        for code: String
    ) -> MeasurementDisplayVariant? {
        RuuviCloudSensorVisibilityCode.parse(code)?.variant
    }

    private static func makeEntries(
        for supportedTypes: [MeasurementType]
    ) -> [MeasurementDisplayEntry] {
        supportedTypes.flatMap { type in
            measurementVariants(for: type).map { variant in
                let defaults = measurementBaseline(for: type, variant: variant)
                return MeasurementDisplayEntry(
                    variant.type,
                    temperatureUnit: variant.temperatureUnit,
                    humidityUnit: variant.humidityUnit,
                    pressureUnit: variant.pressureUnit,
                    visible: defaults.isVisible,
                    contexts: defaults.contexts
                )
            }
        }
    }

    private static func orderedMeasurements(
        for supportedTypes: [MeasurementType]
    ) -> [MeasurementType] {
        var ordered = MeasurementDisplayDefaults.baseMeasurementPriority.filter { baseType in
            supportedTypes.contains { $0.isSameCase(as: baseType) }
        }
        let remaining = supportedTypes.filter { candidate in
            !ordered.contains { $0.isSameCase(as: candidate) }
        }
        ordered.append(contentsOf: remaining)
        return ordered
    }

    private static func measurementBaseline(
        for type: MeasurementType,
        variant: MeasurementDisplayVariant
    ) -> MeasurementDisplayConfiguration {
        if let entry = measurementVariantOverrides[variant] {
            return entry
        }
        if let (_, configuration) = measurementVariantOverrides.first(where: {
            $0.key.baseTypeEquals(type)
        }) {
            return configuration
        }

        switch type {
        case .temperature:
            guard let unit = variant.temperatureUnit else {
                return MeasurementDisplayConfiguration(contexts: .all, isVisible: true)
            }
            let contexts: MeasurementDisplayContext = [.indicator, .graph, .alert]
            let isVisible = unit == .celsius
            return MeasurementDisplayConfiguration(contexts: contexts, isVisible: isVisible)
        case .humidity:
            guard let unit = variant.humidityUnit else {
                return MeasurementDisplayConfiguration(contexts: .all, isVisible: true)
            }
            if unit == .percent {
                return MeasurementDisplayConfiguration(contexts: .all, isVisible: true)
            } else {
                return MeasurementDisplayConfiguration(contexts: [.indicator, .graph, .alert], isVisible: false)
            }
        case .pressure:
            guard let unit = variant.pressureUnit else {
                return MeasurementDisplayConfiguration(contexts: .all, isVisible: true)
            }
            return MeasurementDisplayConfiguration(contexts: .all, isVisible: unit == .hectopascals)
        default:
            return MeasurementDisplayConfiguration(contexts: .all, isVisible: true)
        }
    }

    private static func measurementVariants(
        for type: MeasurementType
    ) -> [MeasurementDisplayVariant] {
        switch type {
        case .temperature:
            return [
                MeasurementDisplayVariant(type: .temperature, temperatureUnit: .celsius),
                MeasurementDisplayVariant(type: .temperature, temperatureUnit: .fahrenheit),
                MeasurementDisplayVariant(type: .temperature, temperatureUnit: .kelvin),
            ]
        case .humidity:
            return [
                MeasurementDisplayVariant(type: .humidity, humidityUnit: .percent),
                MeasurementDisplayVariant(type: .humidity, humidityUnit: .gm3),
                MeasurementDisplayVariant(type: .humidity, humidityUnit: .dew),
            ]
        case .pressure:
            return [
                MeasurementDisplayVariant(type: .pressure, pressureUnit: .newtonsPerMetersSquared),
                MeasurementDisplayVariant(type: .pressure, pressureUnit: .hectopascals),
                MeasurementDisplayVariant(type: .pressure, pressureUnit: .millimetersOfMercury),
                MeasurementDisplayVariant(type: .pressure, pressureUnit: .inchesOfMercury),
            ]
        default:
            return [MeasurementDisplayVariant(type: type)]
        }
    }

    /// Applies user preference to the template profile (reorder + visibility).
    private static func applyMeasurementPreference(
        for sensorId: String,
        to profile: MeasurementDisplayProfile
    ) -> MeasurementDisplayProfile {
        let preference = measurementDisplayPreference(for: sensorId)
        return applyMeasurementPreference(preference: preference, to: profile)
    }

    private static func applyMeasurementPreference(
        preference: MeasurementDisplayPreference?,
        to profile: MeasurementDisplayProfile
    ) -> MeasurementDisplayProfile {
        guard let preference,
            !preference.defaultDisplayOrder
        else {
            return profile
        }
        return MeasurementDisplayProfile(
            entries: reorderEntries(
                profile.entries,
                using: preference
            )
        )
    }

    private static func applyPreferredUnitsIfNeeded(
        _ profile: MeasurementDisplayProfile,
        preference: MeasurementDisplayPreference?
    ) -> MeasurementDisplayProfile {
        guard preference?.defaultDisplayOrder ?? true else { return profile }
        return applyPreferredUnits(to: profile)
    }

    private static func applyPreferredUnits(
        to profile: MeasurementDisplayProfile
    ) -> MeasurementDisplayProfile {
        let preferredUnits = preferredUnitsSnapshot()
        let preferredTemperatureUnit = temperatureUnit(from: preferredUnits.temperatureUnit)
        var entries = profile.entries
        entries = applyPreferredUnitVisibility(
            for: .temperature,
            in: entries,
            matches: { entry in
                entry.variant.temperatureUnit == preferredTemperatureUnit
            }
        )
        entries = applyPreferredUnitVisibility(
            for: .humidity,
            in: entries,
            matches: { entry in
                entry.variant.humidityUnit == preferredUnits.humidityUnit
            }
        )
        entries = applyPreferredUnitVisibility(
            for: .pressure,
            in: entries,
            matches: { entry in
                entry.variant.pressureUnit == preferredUnits.pressureUnit
            }
        )
        return MeasurementDisplayProfile(entries: entries)
    }

    private static func applyPreferredUnitVisibility(
        for type: MeasurementType,
        in entries: [MeasurementDisplayEntry],
        matches predicate: (MeasurementDisplayEntry) -> Bool
    ) -> [MeasurementDisplayEntry] {
        var updatedEntries = entries
        let indices = entries.indices.filter { entries[$0].variant.type.isSameCase(as: type) }
        guard !indices.isEmpty else { return entries }

        guard let preferredIndex = indices.first(where: { predicate(entries[$0]) }) else {
            return entries
        }

        for index in indices {
            updatedEntries[index].isVisible = index == preferredIndex
        }
        return updatedEntries
    }

    private static func temperatureUnit(from unit: UnitTemperature) -> TemperatureUnit {
        switch unit {
        case .fahrenheit:
            return .fahrenheit
        case .kelvin:
            return .kelvin
        default:
            return .celsius
        }
    }

    private static func reorderEntries(
        _ entries: [MeasurementDisplayEntry],
        using preference: MeasurementDisplayPreference
    ) -> [MeasurementDisplayEntry] {
        let resolvedVariants = normalizedMeasurementVariants(from: preference.displayOrderCodes)
        guard !resolvedVariants.isEmpty else {
            return entries
        }

        if preference.defaultDisplayOrder {
            var updatedEntries = entries
            var additions: [MeasurementDisplayEntry] = []
            for variant in resolvedVariants {
                if let idx = updatedEntries.firstIndex(where: { $0.variant == variant }) {
                    updatedEntries[idx].isVisible = true
                } else {
                    let defaults = measurementBaseline(for: variant.type, variant: variant)
                    additions.append(
                        MeasurementDisplayEntry(
                            variant.type,
                            temperatureUnit: variant.temperatureUnit,
                            humidityUnit: variant.humidityUnit,
                            pressureUnit: variant.pressureUnit,
                            visible: true,
                            contexts: defaults.contexts
                        ))
                }
            }
            updatedEntries.append(contentsOf: additions)
            return updatedEntries
        } else {
            var workingEntries = entries
            var orderedEntries: [MeasurementDisplayEntry] = []
            for variant in resolvedVariants {
                if let idx = workingEntries.firstIndex(where: { $0.variant == variant }) {
                    var entry = workingEntries.remove(at: idx)
                    entry.isVisible = true
                    orderedEntries.append(entry)
                } else {
                    let defaults = measurementBaseline(for: variant.type, variant: variant)
                    orderedEntries.append(
                        MeasurementDisplayEntry(
                            variant.type,
                            temperatureUnit: variant.temperatureUnit,
                            humidityUnit: variant.humidityUnit,
                            pressureUnit: variant.pressureUnit,
                            visible: true,
                            contexts: defaults.contexts
                        ))
                }
            }
            return orderedEntries
        }
    }

    private static func normalizedMeasurementVariants(
        from codes: [String]
    ) -> [MeasurementDisplayVariant] {
        var seen: [MeasurementDisplayVariant] = []
        for code in codes {
            guard let variant = measurementVariant(for: code),
                !seen.contains(where: { $0 == variant })
            else { continue }
            seen.append(variant)
        }
        return seen
    }

    private static func normalizedAlertVariants(
        _ variants: [MeasurementDisplayVariant],
        profile: MeasurementDisplayProfile,
        preferredTemperature: UnitTemperature?,
        preferredPressure: UnitPressure?
    ) -> [MeasurementDisplayVariant] {
        var normalized = variants
        let temperatureUnit = resolvedTemperatureUnit(preferredTemperature)
        let pressureUnit = preferredPressure ?? .hectopascals

        if profile.hasVisibleVariant(of: .temperature) {
            let preferredVariant = MeasurementDisplayVariant(
                type: .temperature,
                temperatureUnit: temperatureUnit
            )
            if !normalized.contains(preferredVariant) {
                normalized.insert(preferredVariant, at: 0)
            }
        }

        if profile.hasVisibleVariant(of: .pressure) {
            let preferredVariant = MeasurementDisplayVariant(
                type: .pressure,
                pressureUnit: pressureUnit
            )
            if !normalized.contains(preferredVariant) {
                normalized.append(preferredVariant)
            }
        }

        if profile.hasVisibleVariant(of: .humidity) {
            let humidityPercentVariant = MeasurementDisplayVariant(
                type: .humidity,
                humidityUnit: .percent
            )
            if !normalized.contains(humidityPercentVariant) {
                normalized.append(humidityPercentVariant)
            }
        }

        return normalized
    }

    private static func resolvedTemperatureUnit(
        _ unit: UnitTemperature?
    ) -> TemperatureUnit {
        guard let unit else {
            return temperatureUnit(
                from: preferredUnitsSnapshot().temperatureUnit
            )
        }
        switch unit {
        case .fahrenheit:
            return .fahrenheit
        case .kelvin:
            return .kelvin
        default:
            return .celsius
        }
    }
}

private extension MeasurementDisplayProfile {
    func hasVisibleVariant(of type: MeasurementType) -> Bool {
        entries.contains { entry in
            entry.type.isSameCase(as: type) && entry.isVisible
        }
    }
}

// swiftlint:enable file_length
