// swiftlint:disable file_length

import Foundation
import UIKit
import RuuviOntology
import RuuviReactor
import RuuviStorage
import RuuviService
import RuuviLocal
import RuuviDaemon

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

    // MARK: - Properties
    weak var delegate: RuuviTagDataServiceDelegate?

    private var ruuviTags: [AnyRuuviTagSensor] = []
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var sensorSettingsList: [SensorSettings] = []

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
        flags: RuuviLocalFlags
    ) {
        self.ruuviReactor = ruuviReactor
        self.ruuviStorage = ruuviStorage
        self.measurementService = measurementService
        self.ruuviSensorPropertiesService = ruuviSensorPropertiesService
        self.settings = settings
        self.flags = flags
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

        let sensorSettings = sensorSettingsList.first { settings in
            (settings.luid?.any != nil && settings.luid?.any == sensor.luid?.any) ||
            (settings.macId?.any != nil && settings.macId?.any == sensor.macId?.any)
        }

        let snapshot = snapshots[snapshotIndex]

        DispatchQueue.main.async {
            snapshot.updateFromRecord(
                record,
                sensor: sensor,
                measurementService: self.measurementService,
                flags: self.flags,
                sensorSettings: sensorSettings
            )

            if !self.settings.syncExtensiveChangesInProgress {
                self.delegate?.sensorDataService(self, didUpdateSnapshot: snapshot)
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
        return sensorSettingsList
    }

    func getSensorSettings(for sensorId: String) -> SensorSettings? {
        return sensorSettingsList.first(where: { settings in
            settings.luid?.value == sensorId || settings.macId?.any == sensorId.mac.any
        })
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
                        snapshot.updateBackgroundImage(image)
                        if !self.settings.syncExtensiveChangesInProgress {
                            self.delegate?.sensorDataService(self, didUpdateSnapshot: snapshot)
                        }
                    }
                })
        }
    }
}

extension RuuviTagDataService: RuuviServiceMeasurementDelegate {
    func measurementServiceDidUpdateUnit() {
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
                    AnyRuuviTagSensor
                )
            ] = []

            for tag in self.ruuviTags {
                let snapshot = self.createSnapshot(from: tag)

                // Load latest record synchronously for initial build
                let record = self.ruuviStorage.cachedLatestBlocking(for: tag)
                let settings = self.sensorSettingsList.first { $0.id == tag.id }

                snapshotsWithRecords.append((snapshot, record, settings, tag))
            }

            DispatchQueue.main.async {
                var newSnapshots: [RuuviTagCardSnapshot] = []

                // Update snapshots on main thread to avoid @Published property race conditions
                for (snapshot, record, settings, sensor) in snapshotsWithRecords {
                    if let record = record {
                        let updatedRecord = record.with(sensorSettings: settings)
                        snapshot.updateFromRecord(
                            updatedRecord,
                            sensor: sensor,
                            measurementService: self.measurementService,
                            flags: self.flags,
                            sensorSettings: settings
                        )
                    }

                    // Preserve existing in-memory background image to avoid UI flash
                    for snapshot in newSnapshots {
                        if let existing = self.snapshots.first(where: { $0.id == snapshot.id }) {
                            snapshot.displayData.background = existing.displayData.background
                        }
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

    func createSnapshot(from sensor: AnyRuuviTagSensor) -> RuuviTagCardSnapshot {
        return RuuviTagCardSnapshot.create(
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
    }

    // swiftlint:disable:next function_body_length
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

            let settings = self.sensorSettingsList.first { $0.id == sensor.id }
            let updatedRecord = record.with(sensorSettings: settings)

            DispatchQueue.main.async {
                snapshot.updateFromRecord(
                    updatedRecord,
                    sensor: sensor,
                    measurementService: self.measurementService,
                    flags: self.flags,
                    sensorSettings: settings
                )

                if !self.settings.syncExtensiveChangesInProgress {
                    self.delegate?.sensorDataService(self, didUpdateSnapshot: snapshot)
                }
            }
        }
    }

    func updateSensorSnapshot(sensor: AnyRuuviTagSensor) {
        guard let snapshotIndex = snapshots.firstIndex(where: { $0.id == sensor.id }) else { return }

        let snapshot = snapshots[snapshotIndex]

        // Ensure we update @Published properties on the main thread
        DispatchQueue.main.async {
            // Update basic sensor information
            let invalidateLayout = snapshot.displayData.name != sensor.name
            snapshot.displayData.name = sensor.name
            snapshot.displayData.version = sensor.version
            snapshot.metadata.isCloud = sensor.isCloud
            snapshot.metadata.isOwner = sensor.isOwner
            snapshot.connectionData.isConnectable = sensor.isConnectable

            // Update metadata with new sensor information
            snapshot.updateMetadata(
                isCloud: sensor.isCloud,
                isOwner: sensor.isOwner,
                isConnectable: sensor.isConnectable
            )

            if !self.settings.syncExtensiveChangesInProgress {
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
                        self.sensorSettingsList.append(sensorSettings)
                        self.applySensorSettings(sensorSettings, to: sensor)

                    case let .update(sensorSettings):
                        self.updateSensorSettings(sensorSettings, for: sensor)

                    case let .delete(sensorSettings):
                        if let index = self.sensorSettingsList.firstIndex(where: { $0.id == sensorSettings.id }) {
                            self.sensorSettingsList.remove(at: index)
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
        if let index = sensorSettingsList.firstIndex(where: { $0.id == sensorSettings.id }) {
            sensorSettingsList[index] = sensorSettings
        } else {
            sensorSettingsList.append(sensorSettings)
        }

        applySensorSettings(sensorSettings, to: sensor)
    }

    func applySensorSettings(_ sensorSettings: SensorSettings?, to sensor: AnyRuuviTagSensor) {
        guard let snapshot = snapshots.first(where: { $0.id == sensor.id }) else { return }

        // If we have a current record, update it with new settings
        if snapshot.lastUpdated != nil,
            let lastRecord = snapshot.latestRawRecord {

            DispatchQueue.main.async {
                snapshot.updateFromRecord(
                    lastRecord.with(sensorSettings: sensorSettings),
                    sensor: sensor,
                    measurementService: self.measurementService,
                    flags: self.flags,
                    sensorSettings: sensorSettings
                )

                if !self.settings.syncExtensiveChangesInProgress {
                    self.delegate?.sensorDataService(self, didUpdateSnapshot: snapshot)
                }
            }
        } else {
            ruuviStorage.readLatest(sensor).on { [weak self] record in
                guard let self = self, let record = record else { return }

                let updatedRecord = record.with(sensorSettings: sensorSettings)

                DispatchQueue.main.async {
                    snapshot.updateFromRecord(
                        updatedRecord,
                        sensor: sensor,
                        measurementService: self.measurementService,
                        flags: self.flags,
                        sensorSettings: sensorSettings
                    )

                    if !self.settings.syncExtensiveChangesInProgress {
                        self.delegate?.sensorDataService(self, didUpdateSnapshot: snapshot)
                    }
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
                        let sensorSettings = self.sensorSettingsList.first { settings in
                            (settings.luid?.any != nil && settings.luid?.any == sensor.luid?.any) ||
                            (settings.macId?.any != nil && settings.macId?.any == sensor.macId?.any)
                        }

                        let updatedRecord = record.with(
                            sensorSettings: sensorSettings
                        )

                        DispatchQueue.main
                            .async {
                                snapshot
                                    .updateFromRecord(
                                        updatedRecord,
                                        sensor: sensor,
                                        measurementService: self.measurementService,
                                        flags: self.flags,
                                        sensorSettings: sensorSettings
                                    )

                                if !self.settings.syncExtensiveChangesInProgress {
                                    self.delegate?
                                        .sensorDataService(
                                            self,
                                            didUpdateSnapshot: snapshot
                                        )
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

// swiftlint:enable file_length
