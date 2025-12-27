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
protocol RuuviTagDataServiceDelegate: AnyObject {
    func sensorDataService(
        _ service: RuuviTagDataService,
        didUpdateSnapshots snapshots: [RuuviTagCardSnapshot],
        withAnimation: Bool
    )
    func sensorDataService(
        _ service: RuuviTagDataService, didUpdateSnapshot
        snapshot: RuuviTagCardSnapshot,
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
        _ service: RuuviTagDataService, didUpdateSnapshot
        snapshot: RuuviTagCardSnapshot,
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
                   sensorLuid == luid {
                    return true
                }
                if let sensorMac = sensor.macId?.any,
                   let mac = candidate.macId?.any,
                   sensorMac == mac {
                    return true
                }
                return false
            }
        }
    }

    // MARK: - Background Loading
    private var backgroundLoadingQueue = DispatchQueue(label: "com.ruuvi.background.loading", qos: .utility)

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
        ruuviPool: RuuviPool
    ) {
        self.ruuviReactor = ruuviReactor
        self.ruuviStorage = ruuviStorage
        self.measurementService = measurementService
        self.ruuviSensorPropertiesService = ruuviSensorPropertiesService
        self.settings = settings
        self.flags = flags
        self.ruuviPool = ruuviPool
        Self.setPreferredUnits(measurementService.units)
    }

    deinit {
        stopObservingSensors()
    }

    // MARK: - Public Interface
    func startObservingSensors() {
        observeRuuviTags()
        observeBackgroundChanges()
        observeUnitChanges()
    }

    func stopObservingSensors() {
        ruuviTagToken?.invalidate()
        ruuviTagObserveLastRecordTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.forEach { $0.invalidate() }

        ruuviTagToken = nil
        ruuviTagObserveLastRecordTokens.removeAll()
        sensorSettingsTokens.removeAll()

        backgroundToken?.invalidate()
        backgroundToken = nil
    }

    func updateSnapshot(for sensorId: String, with record: RuuviTagSensorRecord) {
        guard let snapshotIndex = snapshots.firstIndex(where: { $0.id == sensorId }),
              let sensor = ruuviTags.first(where: { $0.id == sensorId }) else { return }

        let sensorSettings = matchingSensorSettings(for: sensor)

        let snapshot = snapshots[snapshotIndex]

        let enrichedRecord = sensorSettings != nil ? record.with(sensorSettings: sensorSettings) : record

        DispatchQueue.main.async {
            let didUpdate = snapshot.updateFromRecord(
                enrichedRecord,
                sensor: sensor,
                measurementService: self.measurementService,
                flags: self.flags,
                sensorSettings: sensorSettings
            )

            let availableVariants = self.availableIndicatorVariants(
                from: enrichedRecord,
                sensor: sensor,
                snapshot: snapshot
            )

            let visibilityChanged = self.updateMeasurementVisibilityMetadata(
                for: snapshot,
                sensor: sensor,
                sensorSettings: sensorSettings,
                availableVariants: availableVariants
            )

            if visibilityChanged {
                self.rebuildIndicatorGrid(
                    for: snapshot,
                    sensor: sensor,
                    sensorSettings: sensorSettings
                )
            }
            if visibilityChanged {
                self.publishSnapshotUpdate(snapshot, force: true)
            } else if didUpdate {
                self.publishSnapshotUpdate(snapshot)
            }
        }
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
        ruuviSensorPropertiesService.set(name: newName, for: sensor)
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
                (settings.luid != nil && (settings.luid?.value == sensorId)) ||
                (settings.macId != nil && (settings.macId?.any == sensorId.mac.any))
            })
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
        backgroundLoadingQueue.async { [weak self] in
            guard let self = self else { return }

            self.ruuviSensorPropertiesService.getImage(for: sensor)
                .on(success: { [weak self] image in
                    guard let self = self else { return }

                    DispatchQueue.main.async {
                        let didUpdate = snapshot.updateBackgroundImage(image)
                        if didUpdate && !self.settings.syncExtensiveChangesInProgress {
                            self.delegate?.sensorDataService(self, didUpdateSnapshot: snapshot)
                        }
                    }
                })
        }
    }
}

extension RuuviTagDataService: RuuviServiceMeasurementDelegate {
    func measurementServiceDidUpdateUnit() {
        Self.setPreferredUnits(measurementService.units)
        buildInitialSnapshots()
    }
}

// MARK: - Private Implementation
private extension RuuviTagDataService {

    func observeBackgroundChanges() {
        backgroundToken?.invalidate()
        backgroundToken = NotificationCenter.default.addObserver(
            forName: .BackgroundPersistenceDidChangeBackground,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

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
        ruuviTagToken = ruuviReactor.observe { [weak self] change in
            guard let self = self else { return }

            switch change {
            case let .initial(ruuviTags):
                let reorderedTags = ruuviTags.reordered()
                self.ruuviTags = reorderedTags
                self.buildInitialSnapshots()
                self.observeSensorSettings()
                self.restartObservingRuuviTagLastRecords()

            case let .insert(sensor):
                self.ruuviTags.append(sensor.any)
                self.addSensorSnapshot(sensor: sensor.any)
                self.observeSensorSettings()
                self.restartObservingRuuviTagLastRecords()
                // TODO: Remove these calls after fixing the daemon observation
                self.notifyRestartAdvertisementDaemon()
                self.notifyRestartHeartBeatDaemon()

            case let .delete(sensor):
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
                    ($0.macId != nil && $0.macId?.any == sensor.macId?.any) ||
                    ($0.luid != nil && $0.luid?.any == sensor.luid?.any)
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

    // swiftlint:disable:next function_body_length
    func buildInitialSnapshots() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var snapshotsWithRecords: [
                // swiftlint:disable:next large_tuple
                (
                    RuuviTagCardSnapshot,
                    RuuviTagSensorRecord?,
                    SensorSettings?,
                    AnyRuuviTagSensor,
                    Bool
                )
            ] = []

            for tag in self.ruuviTags {
                let existingSnapshot = self.snapshots.first { current in
                    self.snapshot(current, matches: tag)
                }
                let snapshot = existingSnapshot ?? self.createSnapshot(from: tag)

                // Load latest record synchronously for initial build
                let record = self.ruuviStorage.cachedLatestBlocking(for: tag)
                let settings = self.matchingSensorSettings(for: tag)

                self.updateMeasurementDisplayPreference(for: tag, settings: settings)

                snapshotsWithRecords.append((snapshot, record, settings, tag, existingSnapshot != nil))
            }

            DispatchQueue.main.async {
                var newSnapshots: [RuuviTagCardSnapshot] = []

                // Update snapshots on main thread to avoid @Published property race conditions
                for (snapshot, record, settings, sensor, wasReused) in snapshotsWithRecords {
                    self.populateSnapshot(snapshot, with: sensor)

                    if let record = record {
                        let updatedRecord = record.with(sensorSettings: settings)
                        snapshot.updateFromRecord(
                            updatedRecord,
                            sensor: sensor,
                            measurementService: self.measurementService,
                            flags: self.flags,
                            sensorSettings: settings
                        )

                        let availableVariants = self.availableIndicatorVariants(
                            from: updatedRecord,
                            sensor: sensor,
                            snapshot: snapshot
                        )
                        _ = self.updateMeasurementVisibilityMetadata(
                            for: snapshot,
                            sensor: sensor,
                            sensorSettings: settings,
                            availableVariants: availableVariants
                        )
                    } else {
                        _ = self.updateMeasurementVisibilityMetadata(
                            for: snapshot,
                            sensor: sensor,
                            sensorSettings: settings,
                            availableVariants: snapshot.displayData.measurementVisibility?.availableVariants
                        )
                    }

                    if !wasReused,
                       let existing = self.snapshots.first(where: { $0.id == snapshot.id }) {
                        snapshot.displayData.background = existing.displayData.background
                    }

                    newSnapshots.append(snapshot)
                }

                let orderedSnapshots = self.reorderSnapshots(
                    newSnapshots,
                    with: self.settings.dashboardSensorOrder
                )
                self.snapshots = orderedSnapshots

                // Load backgrounds only for snapshots that don't have one
                for snapshot in self.snapshots where snapshot.displayData.background == nil {
                    if let sensor = self.ruuviTags.first(where: { $0.id == snapshot.id }) {
                        self.loadBackground(for: snapshot, sensor: sensor)
                    }
                }

                if !self.settings.syncExtensiveChangesInProgress {
                    self.delegate?.sensorDataService(
                        self,
                        didUpdateSnapshots: self.snapshots,
                        withAnimation: false
                    )
                }
            }
        }
    }

    private func snapshot(
        _ snapshot: RuuviTagCardSnapshot,
        matches sensor: AnyRuuviTagSensor
    ) -> Bool {
        if let snapshotMac = snapshot.identifierData.mac,
           let sensorMac = sensor.macId,
           snapshotMac.any == sensorMac.any {
            return true
        }
        if let snapshotLuid = snapshot.identifierData.luid,
           let sensorLuid = sensor.luid,
           snapshotLuid.any == sensorLuid.any {
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

        // Load latest record asynchronously
        ruuviStorage.readLatest(sensor).on { [weak self] record in
            guard let self = self, let record = record else { return }

            let settings = self.matchingSensorSettings(for: sensor)
            let updatedRecord = record.with(sensorSettings: settings)

            DispatchQueue.main.async {
                let didUpdate = snapshot.updateFromRecord(
                    updatedRecord,
                    sensor: sensor,
                    measurementService: self.measurementService,
                    flags: self.flags,
                    sensorSettings: settings
                )

                let availableVariants = self.availableIndicatorVariants(
                    from: updatedRecord,
                    sensor: sensor,
                    snapshot: snapshot
                )

                let visibilityChanged = self.updateMeasurementVisibilityMetadata(
                    for: snapshot,
                    sensor: sensor,
                    sensorSettings: settings,
                    availableVariants: availableVariants
                )

                if visibilityChanged {
                    self.publishSnapshotUpdate(snapshot, force: true)
                } else if didUpdate {
                    self.publishSnapshotUpdate(snapshot)
                }
            }
        }
    }

    func updateSensorSnapshot(sensor: AnyRuuviTagSensor) {
        guard let snapshotIndex = snapshots.firstIndex(where: { $0.id == sensor.id }) else { return }

        let snapshot = snapshots[snapshotIndex]

        // Ensure we update @Published properties on the main thread
        DispatchQueue.main.async {
            let previousName = snapshot.displayData.name
            // Update basic sensor information
            let didUpdate = self.populateSnapshot(snapshot, with: sensor)
            let invalidateLayout = previousName != snapshot.displayData.name

            if didUpdate && !self.settings.syncExtensiveChangesInProgress {
                self.delegate?
                    .sensorDataService(
                        self,
                        didUpdateSnapshot: snapshot,
                        invalidateLayout: invalidateLayout
                    )
            }
        }
    }

    func observeSensorSettings() {
        sensorSettingsTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()

        for sensor in ruuviTags {
            sensorSettingsTokens.append(
                ruuviReactor.observe(sensor) { [weak self] change in
                    guard let self = self else { return }

                    switch change {
                    case let .insert(sensorSettings):
                        self.updateSensorSettingsList { $0.append(sensorSettings) }
                        self.applySensorSettings(sensorSettings, to: sensor)

                    case let .update(sensorSettings):
                        self.updateSensorSettings(sensorSettings, for: sensor)

                    case let .delete(sensorSettings):
                        self.updateSensorSettingsList { list in
                            if let index = list.firstIndex(where: { $0.id == sensorSettings.id }) {
                                list.remove(at: index)
                            }
                        }
                        self.applySensorSettings(nil, to: sensor)

                    case let .initial(initialSettings):
                        initialSettings.forEach { self.updateSensorSettings($0, for: sensor) }

                    case let .error(error):
                        if !self.settings.syncExtensiveChangesInProgress {
                            self.delegate?.sensorDataService(self, didEncounterError: error)
                        }
                    }
                }
            )
        }
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

        let processRecord: (RuuviTagSensorRecord) -> Void = { [weak self, weak snapshot] rawRecord in
            guard let self, let snapshot else { return }
            let enrichedRecord = rawRecord.with(sensorSettings: sensorSettings)
            self.updateSnapshot(
                snapshot,
                with: enrichedRecord,
                sensor: sensor,
                sensorSettings: sensorSettings
            )
        }

        if snapshot.lastUpdated != nil, let lastRecord = snapshot.latestRawRecord {
            processRecord(lastRecord)
        } else {
            ruuviStorage.readLatest(sensor).on { record in
                guard let record else { return }
                processRecord(record)
            }
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func updateMeasurementDisplayPreference(
        for sensor: AnyRuuviTagSensor,
        settings: SensorSettings?
    ) {
        guard flags.showVisibilitySettings else {
            RuuviTagDataService.clearMeasurementDisplayPreference(for: sensor.id)
            if let snapshot = snapshots.first(where: { $0.id == sensor.id }) {
                let didChange = updateMeasurementVisibilityMetadata(
                    for: snapshot,
                    sensor: sensor,
                    sensorSettings: settings,
                    availableVariants: snapshot.displayData.measurementVisibility?.availableVariants
                )
                if didChange {
                    rebuildIndicatorGrid(for: snapshot, sensor: sensor, sensorSettings: settings)
                }
                DispatchQueue.main.async {
                    if didChange {
                        self.publishSnapshotUpdate(snapshot, force: true)
                    } else {
                        self.publishSnapshotUpdate(snapshot)
                    }
                }
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
                DispatchQueue.main.async {
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

            DispatchQueue.main.async {
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

        for sensor in ruuviTags {
            let token = ruuviReactor.observeLatest(sensor) { [weak self] changes in
                guard let self = self else { return }

                if case let .update(anyRecord) = changes,
                   let record = anyRecord,
                   let snapshot = self.snapshots.first(where: { $0.id == sensor.id }) {

                    DispatchQueue.global(qos: .userInitiated).async {
                        let sensorSettings = self.matchingSensorSettings(for: sensor)

                        let updatedRecord = record.with(
                            sensorSettings: sensorSettings
                        )

                        DispatchQueue.main
                            .async {
                                let didUpdate = snapshot
                                    .updateFromRecord(
                                        updatedRecord,
                                        sensor: sensor,
                                        measurementService: self.measurementService,
                                        flags: self.flags,
                                        sensorSettings: sensorSettings
                                    )

                                let availableVariants = self.availableIndicatorVariants(
                                    from: updatedRecord,
                                    sensor: sensor,
                                    snapshot: snapshot
                                )

                                let visibilityChanged = self.updateMeasurementVisibilityMetadata(
                                    for: snapshot,
                                    sensor: sensor,
                                    sensorSettings: sensorSettings,
                                    availableVariants: availableVariants
                                )

                                if visibilityChanged {
                                    self.publishSnapshotUpdate(snapshot, force: true)
                                } else if didUpdate {
                                    self.publishSnapshotUpdate(snapshot)
                                }
                            }
                    }
                }
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
                first.displayData.name.lowercased() < second.displayData.name.lowercased()
            }
        }

        // Manual sorting based on MAC IDs
        return snapshots.sorted { first, second in
            guard let firstMacId = first.identifierData.mac?.value,
                  let secondMacId = second.identifierData.mac?.value else { return false }

            let firstIndex = orderedIds.firstIndex(of: firstMacId) ?? Int.max
            let secondIndex = orderedIds.firstIndex(of: secondMacId) ?? Int.max
            return firstIndex < secondIndex
        }
    }

    func notifyRestartAdvertisementDaemon() {
        NotificationCenter
            .default
            .post(
                name: .RuuviTagAdvertisementDaemonShouldRestart,
                object: nil,
                userInfo: nil
            )
    }

    func notifyRestartHeartBeatDaemon() {
        NotificationCenter
            .default
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
        let canBeClaimed = !sensor.isClaimed &&
            sensor.macId != nil &&
            (sensor.owner == nil || sensor.isOwner)
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
            let tempOffset = measurementService
                .temperatureOffsetCorrectionString(for: sensorSettings.temperatureOffset ?? 0)
            if updatedCalibration.temperatureOffset != tempOffset {
                updatedCalibration.temperatureOffset = tempOffset
            }
            let humidityOffset = measurementService
                .humidityOffsetCorrectionString(for: sensorSettings.humidityOffset ?? 0)
            if updatedCalibration.humidityOffset != humidityOffset {
                updatedCalibration.humidityOffset = humidityOffset
            }
            let pressureOffset = measurementService
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
        guard force || !settings.syncExtensiveChangesInProgress else { return }
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
        guard flags.showVisibilitySettings else {
            return snapshot.updateMeasurementVisibility(nil)
        }

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
        let availableSource = availableVariants
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

    private func syncMaxShareCount(
        for snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor
    ) {
        ruuviPool
            .readSensorSubscriptionSettings(sensor)
            .on(success: { [weak self, weak snapshot] subscription in
                guard let self, let snapshot else { return }

                let newValue = subscription?.maxSharesPerSensor
                DispatchQueue.main.async {
                    guard snapshot.ownership.maxShareCount != newValue else { return }
                    snapshot.ownership.maxShareCount = newValue

                    if !self.settings.syncExtensiveChangesInProgress {
                        self.delegate?.sensorDataService(self, didUpdateSnapshot: snapshot)
                    }
                }
            })
    }

    private func updateSnapshot(
        _ snapshot: RuuviTagCardSnapshot,
        with record: RuuviTagSensorRecord,
        sensor: AnyRuuviTagSensor,
        sensorSettings: SensorSettings?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let didUpdate = snapshot.updateFromRecord(
                record,
                sensor: sensor,
                measurementService: self.measurementService,
                flags: self.flags,
                sensorSettings: sensorSettings
            )

            let availableVariants = self.availableIndicatorVariants(
                from: record,
                sensor: sensor,
                snapshot: snapshot
            )

            let visibilityChanged = self.updateMeasurementVisibilityMetadata(
                for: snapshot,
                sensor: sensor,
                sensorSettings: sensorSettings,
                availableVariants: availableVariants
            )

            if visibilityChanged {
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
                  ) else {
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
        guard let baseSensor = sensor ?? ruuviTags.first(where: {
            $0.id == snapshot.id
        }) else { return }
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

// MARK: - RuuviStorage Extension for Blocking Read
extension RuuviStorage {

    /// Synchronously returns the cached latest record (if any) from SQLite.
    /// Call **off** the main thread; waits up to `timeout` for the disk IO.
    func cachedLatestBlocking(
        for sensor: AnyRuuviTagSensor,
        timeout: TimeInterval = 0.15
    ) -> RuuviTagSensorRecord? {

        var record: RuuviTagSensorRecord?
        let sema = DispatchSemaphore(value: 0)

        readLatest(sensor)
            .on(success: { rec in
                record = rec
                sema.signal()
            }, failure: { _ in
                // ignore the error – just surface `nil`
                sema.signal()
            })

        // Block only when *not* on the main thread
        if !Thread.isMainThread {
            _ = sema.wait(timeout: .now() + timeout)
        }
        return record
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
        temperatureUnit: .celsius,
        humidityUnit: .percent,
        pressureUnit: .hectopascals
    )

    static func measurementDisplayProfile(
        for sensor: RuuviTagSensor
    ) -> MeasurementDisplayProfile {
        let preference = measurementDisplayPreference(for: sensor.id)
        let baseProfile = measurementDisplayOverride(for: sensor.id) ??
            defaultMeasurementDisplayProfile(for: sensor)
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
        for snapshot: RuuviTagCardSnapshot
    ) -> MeasurementDisplayProfile {
        let preference = measurementDisplayPreference(for: snapshot.id)
        let baseProfile = measurementDisplayOverride(for: snapshot.id) ??
            defaultMeasurementDisplayProfile(for: snapshot)
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
    private static let measurementVariantOverrides: [
        MeasurementDisplayVariant: MeasurementDisplayConfiguration
    ] = [
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
            contexts: [.indicator, .graph],
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
                return MeasurementDisplayConfiguration(contexts: [.indicator, .graph], isVisible: false)
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
              !preference.defaultDisplayOrder else {
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
                    additions.append(MeasurementDisplayEntry(
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
                    orderedEntries.append(MeasurementDisplayEntry(
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
                  !seen.contains(where: { $0 == variant }) else { continue }
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
        guard let unit else { return .celsius }
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
