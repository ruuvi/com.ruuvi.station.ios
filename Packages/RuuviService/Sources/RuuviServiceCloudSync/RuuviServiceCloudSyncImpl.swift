import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviRepository
import RuuviStorage
import UIKit
// swiftlint:disable file_length

private struct SensorInventorySyncResult {
    var updatedSensors = Set<AnyRuuviTagSensor>()
    var skipImageDownloadIds = Set<String>()
}

private struct LocalSensorSyncChange {
    var updatedSensor: AnyRuuviTagSensor?
    var skipImageDownloadId: String?
}

private struct DisplaySettingsSyncActions {
    let displayOrder: SyncAction
    let defaultOrder: SyncAction
    let description: SyncAction

    var shouldUpdateLocal: Bool {
        displayOrder == .updateLocal
            || defaultOrder == .updateLocal
            || description == .updateLocal
    }

    var shouldQueueLocal: Bool {
        displayOrder == .keepLocalAndQueue
            || defaultOrder == .keepLocalAndQueue
            || description == .keepLocalAndQueue
    }
}

private struct QueuedDisplaySettings {
    let displayOrder: [String]?
    let defaultDisplayOrder: Bool?
    let description: String?
    let includesDescription: Bool

    var hasChanges: Bool {
        displayOrder != nil
            || defaultDisplayOrder != nil
            || includesDescription
    }
}

private struct ResolvedDisplaySettings {
    let displayOrder: [String]?
    let displayOrderLastUpdated: Date?
    let defaultDisplayOrder: Bool?
    let defaultDisplayOrderLastUpdated: Date?
    let description: String?
    let descriptionLastUpdated: Date?
}

// swiftlint:disable:next type_body_length
public final class RuuviServiceCloudSyncImpl: RuuviServiceCloudSync {
    private let ruuviStorage: RuuviStorage
    private let ruuviCloud: RuuviCloud
    private let ruuviPool: RuuviPool
    private var ruuviLocalSettings: RuuviLocalSettings
    private var ruuviLocalSyncState: RuuviLocalSyncState
    private let ruuviLocalImages: RuuviLocalImages
    private let ruuviRepository: RuuviRepository
    private let ruuviLocalIDs: RuuviLocalIDs
    private let alertService: RuuviServiceAlert
    private let ruuviAppSettingsService: RuuviServiceAppSettings
    private let imageDataLoader: (URL) async throws -> Data

    // Private property to keep track of ongoing history sync
    private var ongoingHistorySyncs: Set<AnyRuuviTagSensor> = []

    public init(
        ruuviStorage: RuuviStorage,
        ruuviCloud: RuuviCloud,
        ruuviPool: RuuviPool,
        ruuviLocalSettings: RuuviLocalSettings,
        ruuviLocalSyncState: RuuviLocalSyncState,
        ruuviLocalImages: RuuviLocalImages,
        ruuviRepository: RuuviRepository,
        ruuviLocalIDs: RuuviLocalIDs,
        ruuviAlertService: RuuviServiceAlert,
        ruuviAppSettingsService: RuuviServiceAppSettings,
        imageDataLoader: @escaping (URL) async throws -> Data = { url in
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }
    ) {
        self.ruuviStorage = ruuviStorage
        self.ruuviCloud = ruuviCloud
        self.ruuviPool = ruuviPool
        self.ruuviLocalSettings = ruuviLocalSettings
        self.ruuviLocalSyncState = ruuviLocalSyncState
        self.ruuviLocalImages = ruuviLocalImages
        self.ruuviRepository = ruuviRepository
        self.ruuviLocalIDs = ruuviLocalIDs
        alertService = ruuviAlertService
        self.ruuviAppSettingsService = ruuviAppSettingsService
        self.imageDataLoader = imageDataLoader
    }

    @discardableResult
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func syncSettings() async throws -> RuuviCloudSettings {
        do {
            guard let cloudSettings = try await RuuviServiceError.perform({
            try await self.ruuviCloud.getCloudSettings()
            }) else {
                throw RuuviServiceError.failedToParseNetworkResponse
            }
            if let unitTemperature = cloudSettings.unitTemperature,
               unitTemperature != ruuviLocalSettings.temperatureUnit {
                ruuviLocalSettings.temperatureUnit = unitTemperature
            }
            if let accuracyTemperature = cloudSettings.accuracyTemperature,
               accuracyTemperature != ruuviLocalSettings.temperatureAccuracy {
                ruuviLocalSettings.temperatureAccuracy = accuracyTemperature
            }
            if let unitHumidity = cloudSettings.unitHumidity,
               unitHumidity != ruuviLocalSettings.humidityUnit {
                ruuviLocalSettings.humidityUnit = unitHumidity
            }
            if let accuracyHumidity = cloudSettings.accuracyHumidity,
               accuracyHumidity != ruuviLocalSettings.humidityAccuracy {
                ruuviLocalSettings.humidityAccuracy = accuracyHumidity
            }
            if let unitPressure = cloudSettings.unitPressure,
               unitPressure != ruuviLocalSettings.pressureUnit {
                ruuviLocalSettings.pressureUnit = unitPressure
            }
            if let accuracyPressure = cloudSettings.accuracyPressure,
               accuracyPressure != ruuviLocalSettings.pressureAccuracy {
                ruuviLocalSettings.pressureAccuracy = accuracyPressure
            }
            if let chartShowAllData = cloudSettings.chartShowAllPoints,
               chartShowAllData != !ruuviLocalSettings.chartDownsamplingOn {
                ruuviLocalSettings.chartDownsamplingOn = !chartShowAllData
            }
            if let chartDrawDots = cloudSettings.chartDrawDots,
               chartDrawDots != ruuviLocalSettings.chartDrawDotsOn {
                // Draw dots feature is disabled from v1.3.0 onwards to
                // maintain better performance until we find a better approach to do it.
                ruuviLocalSettings.chartDrawDotsOn = false
            }
            if let chartShowMinMaxAvg = cloudSettings.chartShowMinMaxAvg,
               chartShowMinMaxAvg != ruuviLocalSettings.chartStatsOn {
                ruuviLocalSettings.chartStatsOn = chartShowMinMaxAvg
            }
            if let cloudModeEnabled = cloudSettings.cloudModeEnabled,
               cloudModeEnabled != ruuviLocalSettings.cloudModeEnabled {
                ruuviLocalSettings.cloudModeEnabled = cloudModeEnabled
            }
            if let dashboardEnabled = cloudSettings.dashboardEnabled,
               dashboardEnabled != ruuviLocalSettings.dashboardEnabled {
                ruuviLocalSettings.dashboardEnabled = dashboardEnabled
            }
            if let dashboardType = cloudSettings.dashboardType,
               dashboardType != ruuviLocalSettings.dashboardType {
                ruuviLocalSettings.dashboardType = dashboardType
            }
            if let dashboardTapActionType = cloudSettings.dashboardTapActionType,
               dashboardTapActionType != ruuviLocalSettings.dashboardTapActionType {
                ruuviLocalSettings.dashboardTapActionType = dashboardTapActionType
            }
            if let pushAlertDisabled = cloudSettings.pushAlertDisabled,
               pushAlertDisabled != ruuviLocalSettings.pushAlertDisabled {
                ruuviLocalSettings.pushAlertDisabled = pushAlertDisabled
            }
            if let emailAlertDisabled = cloudSettings.emailAlertDisabled,
               emailAlertDisabled != ruuviLocalSettings.emailAlertDisabled {
                ruuviLocalSettings.emailAlertDisabled = emailAlertDisabled
            }
            if let marketingPreference = cloudSettings.marketingPreference,
               marketingPreference != ruuviLocalSettings.marketingPreference {
                ruuviLocalSettings.marketingPreference = marketingPreference
            }
            if let cloudProfileLanguageCode = cloudSettings.profileLanguageCode {
                if cloudProfileLanguageCode != ruuviLocalSettings.cloudProfileLanguageCode {
                    ruuviLocalSettings.cloudProfileLanguageCode = cloudProfileLanguageCode
                }
            } else {
                let languageCode = ruuviLocalSettings.language.rawValue
                Task {
                    _ = try? await self.ruuviAppSettingsService.set(
                        profileLanguageCode: languageCode
                    )
                }
                ruuviLocalSettings.cloudProfileLanguageCode = languageCode
            }

            if let dashboardSensorOrderString = cloudSettings.dashboardSensorOrder,
               let dashboardSensorOrder = RuuviCloudApiHelper.jsonArrayFromString(dashboardSensorOrderString),
               dashboardSensorOrder != ruuviLocalSettings.dashboardSensorOrder {
                ruuviLocalSettings.dashboardSensorOrder = dashboardSensorOrder
            }

            return cloudSettings
        } catch let error as RuuviServiceError {
            if case .ruuviCloud(.api(.api(.erUnauthorized))) = error {
                postNotification()
            }
            throw error
        }
    }

    @discardableResult
    public func syncImage(sensor: CloudSensor) async throws -> URL {
        guard let pictureUrl = sensor.picture else {
            throw RuuviServiceError.pictureUrlIsNil
        }
        return try await RuuviServiceError.perform {
            let data = try await self.imageDataLoader(pictureUrl)
            guard let image = UIImage(data: data) else {
                throw RuuviServiceError.failedToParseNetworkResponse
            }
            let fileUrl = try await self.ruuviLocalImages.setCustomBackground(
                image: image,
                compressionQuality: 1.0,
                for: sensor.id.mac
            )
            self.ruuviLocalImages.setPictureIsCached(for: sensor)
            return fileUrl
        }
    }

    @discardableResult
    public func syncAll() async throws -> Set<AnyRuuviTagSensor> {
        // IMPORTANT: Execute pending requests FIRST, then sync.
        // We must wait for queued requests to complete before fetching from cloud,
        // otherwise the cloud data will be stale (e.g., old sensor name) and
        // overwrite the local changes the user made while offline.
        // We continue with sync regardless of whether queued requests succeed or fail.
        _ = try? await executePendingRequests()
        _ = try await syncSettings()
        let updatedSensors = try await syncSensors()
        ruuviLocalSyncState.setSyncDate(Date())
        return updatedSensors
    }

    @discardableResult
    public func refreshLatestRecord() async throws -> Bool {
        ruuviLocalSyncState.setSyncStatus(.syncing)
        defer {
            ruuviLocalSyncState.setSyncStatus(.none)
        }
        do {
            _ = try await syncSensors()
            ruuviLocalSyncState.setSyncStatus(.complete)
            ruuviLocalSyncState.setSyncDate(Date())
            return true
        } catch {
            ruuviLocalSyncState.setSyncStatus(.onError)
            throw error
        }
    }

    @discardableResult
    public func syncAllRecords() async throws -> Bool {
        ruuviLocalSettings.isSyncing = true
        ruuviLocalSyncState.setSyncStatus(.syncing)
        defer {
            ruuviLocalSyncState.setSyncStatus(.none)
            ruuviLocalSettings.isSyncing = false
        }
        do {
            _ = try await syncAll()
            ruuviLocalSyncState.setSyncStatus(.complete)
            return true
        } catch {
            ruuviLocalSyncState.setSyncStatus(.onError)
            throw error
        }
    }

    public func executePendingRequests() async throws -> Bool {
        return try await RuuviServiceError.perform {
            let requests = try await self.ruuviStorage.readQueuedRequests()
            guard !requests.isEmpty else { return true }

            for request in requests {
                _ = try? await self.syncQueuedRequest(request: request)
            }

            return true
        }
    }

    private func offsetSyncs(
        cloudSensors: [CloudSensor],
        localSensors: [AnyRuuviTagSensor],
        updatedSensors: Set<AnyRuuviTagSensor>
    ) async throws {
        for (cloudSensor, sensor) in offsetSensorPairs(
            cloudSensors: cloudSensors,
            localSensors: localSensors,
            updatedSensors: updatedSensors
        ) {
            try await syncOffsets(cloudSensor: cloudSensor, sensor: sensor)
        }
    }

    private func offsetSensorPairs(
        cloudSensors: [CloudSensor],
        localSensors: [AnyRuuviTagSensor],
        updatedSensors: Set<AnyRuuviTagSensor>
    ) -> [(cloudSensor: CloudSensor, sensor: AnyRuuviTagSensor)] {
        cloudSensors.compactMap { cloudSensor in
            let matchedSensor = updatedSensors.first {
                cloudSensor.id.isLast3BytesEqual(to: $0.id)
            } ?? localSensors.first {
                cloudSensor.id.isLast3BytesEqual(to: $0.id)
            }
            return matchedSensor.map { (cloudSensor, $0) }
        }
    }

    private func syncOffsets(
        cloudSensor: CloudSensor,
        sensor: AnyRuuviTagSensor
    ) async throws {
        _ = try await RuuviServiceError.perform {
            let localSettings = try? await self.ruuviStorage.readSensorSettings(sensor)
            let fallbackSettings = self.fallbackSensorSettings(
                for: sensor,
                localSettings: localSettings
            )
            let syncAction = SyncCollisionResolver.resolve(
                isOwner: sensor.isOwner,
                localTimestamp: sensor.lastUpdated,
                cloudTimestamp: cloudSensor.lastUpdated
            )

            switch syncAction {
            case .updateLocal:
                return try await self.applyCloudOffsets(
                    cloudSensor: cloudSensor,
                    sensor: sensor,
                    localSettings: localSettings,
                    fallbackSettings: fallbackSettings
                )
            case .keepLocalAndQueue:
                self.queueOffsetUpdatesToCloud(
                    sensor: sensor,
                    settings: self.offsetSettingsToQueue(
                        cloudSensor: cloudSensor,
                        fallbackSettings: fallbackSettings
                    )
                )
                return fallbackSettings
            case .noAction:
                return fallbackSettings
            }
        }
    }

    private func applyCloudOffsets(
        cloudSensor: CloudSensor,
        sensor: AnyRuuviTagSensor,
        localSettings: SensorSettings?,
        fallbackSettings: SensorSettings
    ) async throws -> SensorSettings {
        var lastUpdatedSettings: SensorSettings = fallbackSettings

        if cloudSensor.offsetTemperature != localSettings?.temperatureOffset {
            lastUpdatedSettings = try await ruuviPool.updateOffsetCorrection(
                type: .temperature,
                with: cloudSensor.offsetTemperature,
                of: sensor
            )
        }

        if let offsetHumidity = cloudSensor.offsetHumidity {
            let newHumidityOffset = offsetHumidity / 100
            if newHumidityOffset != localSettings?.humidityOffset {
                lastUpdatedSettings = try await ruuviPool.updateOffsetCorrection(
                    type: .humidity,
                    with: newHumidityOffset,
                    of: sensor
                )
            }
        }

        if let offsetPressure = cloudSensor.offsetPressure {
            let newPressureOffset = offsetPressure / 100
            if newPressureOffset != localSettings?.pressureOffset {
                lastUpdatedSettings = try await ruuviPool.updateOffsetCorrection(
                    type: .pressure,
                    with: newPressureOffset,
                    of: sensor
                )
            }
        }

        return lastUpdatedSettings
    }

    private func offsetSettingsToQueue(
        cloudSensor: CloudSensor,
        fallbackSettings: SensorSettings
    ) -> SensorSettings {
        let queuedTemperatureOffset = offsetToQueue(
            local: fallbackSettings.temperatureOffset,
            cloud: cloudSensor.offsetTemperature
        )
        let queuedHumidityOffset = offsetToQueue(
            local: fallbackSettings.humidityOffset,
            cloud: cloudSensor.offsetHumidity.map { $0 / 100 }
        )
        let queuedPressureOffset = offsetToQueue(
            local: fallbackSettings.pressureOffset,
            cloud: cloudSensor.offsetPressure.map { $0 / 100 }
        )

        return SensorSettingsStruct(
            luid: fallbackSettings.luid,
            macId: fallbackSettings.macId,
            temperatureOffset: queuedTemperatureOffset,
            humidityOffset: queuedHumidityOffset,
            pressureOffset: queuedPressureOffset
        )
    }

    private func offsetToQueue(local: Double?, cloud: Double?) -> Double? {
        guard let local else { return nil }
        return local == cloud ? nil : local
    }

    private func displaySettingsSyncs(
        denseSensors: [RuuviCloudSensorDense]
    ) async throws {
        for denseSensor in denseSensors {
            try await syncDisplaySettings(for: denseSensor)
        }
    }

    private func syncDisplaySettings(for denseSensor: RuuviCloudSensorDense) async throws {
        guard let cloudSettings = denseSensor.settings else { return }

        let sensor = denseSensor.sensor.ruuviTagSensor
        _ = try await RuuviServiceError.perform {
            let localSettings = try? await self.ruuviStorage.readSensorSettings(sensor)
            let fallbackSettings = self.fallbackSensorSettings(
                for: sensor,
                localSettings: localSettings
            )
            let actions = self.displaySettingsActions(
                isOwner: denseSensor.sensor.isOwner,
                localSettings: localSettings,
                cloudSettings: cloudSettings
            )

            self.queueLocalDisplaySettingsIfNeeded(
                sensor: sensor,
                localSettings: localSettings,
                actions: actions
            )

            guard actions.shouldUpdateLocal else { return fallbackSettings }

            return try await self.applyCloudDisplaySettings(
                sensor: sensor,
                localSettings: localSettings,
                cloudSettings: cloudSettings,
                fallbackSettings: fallbackSettings,
                actions: actions
            )
        }
    }

    private func displaySettingsActions(
        isOwner: Bool,
        localSettings: SensorSettings?,
        cloudSettings: RuuviCloudSensorSettings
    ) -> DisplaySettingsSyncActions {
        DisplaySettingsSyncActions(
            displayOrder: SyncCollisionResolver.resolve(
                isOwner: isOwner,
                localTimestamp: localSettings?.displayOrderLastUpdated,
                cloudTimestamp: cloudSettings.displayOrderLastUpdated
            ),
            defaultOrder: SyncCollisionResolver.resolve(
                isOwner: isOwner,
                localTimestamp: localSettings?.defaultDisplayOrderLastUpdated,
                cloudTimestamp: cloudSettings.defaultDisplayOrderLastUpdated
            ),
            description: SyncCollisionResolver.resolve(
                isOwner: isOwner,
                localTimestamp: localSettings?.descriptionLastUpdated,
                cloudTimestamp: cloudSettings.descriptionLastUpdated
            )
        )
    }

    private func queueLocalDisplaySettingsIfNeeded(
        sensor: RuuviTagSensor,
        localSettings: SensorSettings?,
        actions: DisplaySettingsSyncActions
    ) {
        guard actions.shouldQueueLocal else { return }

        let queuedSettings = QueuedDisplaySettings(
            displayOrder: actions.displayOrder == .keepLocalAndQueue
                ? localSettings?.displayOrder
                : nil,
            defaultDisplayOrder: actions.defaultOrder == .keepLocalAndQueue
                ? localSettings?.defaultDisplayOrder
                : nil,
            description: actions.description == .keepLocalAndQueue
                ? localSettings?.description
                : nil,
            includesDescription: actions.description == .keepLocalAndQueue
        )

        guard queuedSettings.hasChanges else { return }

        queueDisplaySettingsToCloud(
            sensor: sensor,
            displayOrder: queuedSettings.displayOrder,
            defaultDisplayOrder: queuedSettings.defaultDisplayOrder,
            description: queuedSettings.description,
            includesDescription: queuedSettings.includesDescription
        )
    }

    private func applyCloudDisplaySettings(
        sensor: RuuviTagSensor,
        localSettings: SensorSettings?,
        cloudSettings: RuuviCloudSensorSettings,
        fallbackSettings: SensorSettings,
        actions: DisplaySettingsSyncActions
    ) async throws -> SensorSettings {
        let resolvedSettings = resolvedDisplaySettings(
            localSettings: localSettings,
            cloudSettings: cloudSettings,
            actions: actions
        )
        var lastUpdatedSettings: SensorSettings = fallbackSettings

        if actions.displayOrder == .updateLocal || actions.defaultOrder == .updateLocal {
            lastUpdatedSettings = try await ruuviPool.updateDisplaySettings(
                for: sensor,
                displayOrder: resolvedSettings.displayOrder,
                defaultDisplayOrder: resolvedSettings.defaultDisplayOrder,
                displayOrderLastUpdated: resolvedSettings.displayOrderLastUpdated,
                defaultDisplayOrderLastUpdated: resolvedSettings.defaultDisplayOrderLastUpdated
            )
        }

        if actions.description == .updateLocal {
            lastUpdatedSettings = try await ruuviPool.updateDescription(
                for: sensor,
                description: resolvedSettings.description,
                descriptionLastUpdated: resolvedSettings.descriptionLastUpdated
            )
        }

        return lastUpdatedSettings
    }

    private func resolvedDisplaySettings(
        localSettings: SensorSettings?,
        cloudSettings: RuuviCloudSensorSettings,
        actions: DisplaySettingsSyncActions
    ) -> ResolvedDisplaySettings {
        ResolvedDisplaySettings(
            displayOrder: actions.displayOrder == .updateLocal
                ? cloudSettings.displayOrderCodes
                : localSettings?.displayOrder,
            displayOrderLastUpdated: actions.displayOrder == .updateLocal
                ? cloudSettings.displayOrderLastUpdated
                : localSettings?.displayOrderLastUpdated,
            defaultDisplayOrder: actions.defaultOrder == .updateLocal
                ? cloudSettings.defaultDisplayOrder
                : localSettings?.defaultDisplayOrder,
            defaultDisplayOrderLastUpdated: actions.defaultOrder == .updateLocal
                ? cloudSettings.defaultDisplayOrderLastUpdated
                : localSettings?.defaultDisplayOrderLastUpdated,
            description: actions.description == .updateLocal
                ? cloudSettings.description
                : localSettings?.description,
            descriptionLastUpdated: actions.description == .updateLocal
                ? cloudSettings.descriptionLastUpdated
                : localSettings?.descriptionLastUpdated
        )
    }

    private func fallbackSensorSettings(
        for sensor: RuuviTagSensor,
        localSettings: SensorSettings?
    ) -> SensorSettings {
        localSettings ?? SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil
        )
    }

    private func subscriptionSyncs(
        cloudSensors: [RuuviCloudSensorDense]
    ) async throws {
        let subscriptions = cloudSensors.compactMap { cloudSensor in
            cloudSensor.subscription?.with(macId: cloudSensor.sensor.id.mac.mac)
        }
        for subscription in subscriptions {
            _ = try await RuuviServiceError.perform {
                try await self.ruuviPool.save(subscription: subscription)
            }
        }
    }

    @discardableResult
    public func sync(sensor: RuuviTagSensor) async throws -> [AnyRuuviTagSensorRecord] {
        // Check if a history sync is already in progress for this sensor
        // and return early if so.
        if ongoingHistorySyncs.contains(sensor.any) {
            return []
        }

        guard let maxHistoryDays = sensor.maxHistoryDays, maxHistoryDays > 0 else {
            return []
        }

        let networkPruningOffset = -TimeInterval(ruuviLocalSettings.networkPruningIntervalHours * 60 * 60)
        let networkPuningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let lastSynDate = ruuviLocalSyncState.getSyncDate(for: sensor.macId)

        var syncFullHistory = false
        if let syncFull = ruuviLocalSyncState.downloadFullHistory(for: sensor.macId),
           syncFull {
            syncFullHistory = true
        }

        ruuviLocalSyncState
            .setSyncStatusHistory(.syncing, for: sensor.macId)
        ongoingHistorySyncs.insert(sensor.any)
        defer {
            ruuviLocalSyncState
                .setSyncStatusHistory(.none, for: sensor.macId)
            ongoingHistorySyncs.remove(sensor.any)
        }
        let since: Date = syncFullHistory ? networkPuningDate : (lastSynDate ?? networkPuningDate)
        do {
            let result = try await syncRecordsOperation(for: sensor, since: since)
            ruuviLocalSyncState.setSyncStatusHistory(.complete, for: sensor.macId)
            ruuviLocalSyncState.setDownloadFullHistory(for: sensor.macId, downloadFull: false)
            if let latestRecordDate = result.map(\.date).max() {
                ruuviLocalSyncState.setSyncDate(
                    latestRecordDate,
                    for: sensor.macId
                )
            }
            return result
        } catch {
            ruuviLocalSyncState
                .setSyncStatusHistory(.onError, for: sensor.macId)
            throw error
        }
    }

    @discardableResult
    public func syncAllHistory() async throws -> Bool {
        return try await RuuviServiceError.perform {
            let localSensors = try await self.ruuviStorage.readAll()
            var sensorsToSync = [AnyRuuviTagSensor]()

            for sensor in localSensors {
                guard sensor.isCloud,
                      let maxHistoryDays = sensor.maxHistoryDays,
                      maxHistoryDays > 0 else {
                    continue
                }

                if try await self.ruuviStorage.readLatest(sensor) != nil {
                    sensorsToSync.append(sensor)
                }
            }

            for sensor in sensorsToSync {
                _ = try await self.sync(sensor: sensor)
            }
            return true
        }
    }

    private lazy var syncRecordsQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    private func syncRecordsOperation(
        for sensor: RuuviTagSensor,
        since: Date
    ) async throws -> [AnyRuuviTagSensorRecord] {
        try await withCheckedThrowingContinuation { continuation in
            let operation = RuuviServiceCloudSyncRecordsOperation(
                sensor: sensor,
                since: since,
                ruuviCloud: ruuviCloud,
                ruuviRepository: ruuviRepository,
                syncState: ruuviLocalSyncState,
                ruuviLocalIDs: ruuviLocalIDs
            )
            operation.completionBlock = { [unowned operation] in
                if let error = operation.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: operation.records)
                }
            }
            syncRecordsQueue.addOperation(operation)
        }
    }

    // This method syncs the sensors, latest measurements and alerts.
    private func syncSensors() async throws -> Set<AnyRuuviTagSensor> {
        let localCloudMacIds = await localCloudSensorMacIds()
        setLatestRecordSyncStatus(.syncing, for: localCloudMacIds)

        do {
            let denseSensors = try await loadDenseSensors()
            syncAlerts(from: denseSensors)

            let cloudSensors = denseSensors.compactMap { sensor in
                sensor.sensor.any
            }
            let updatedSensors = try await self.syncSensors(
                cloudSensors: cloudSensors,
                denseSensor: denseSensors
            )

            markNoHistorySensorsSynced(denseSensors)
            try await updateLatestRecords(from: denseSensors)
            try await addLatestRecordsToHistory(from: denseSensors)

            if shouldSyncHistory {
                _ = try await self.syncAllHistory()
            }

            completeLocalSensorsMissingFromCloud(
                localCloudMacIds: localCloudMacIds,
                denseSensors: denseSensors
            )

            return updatedSensors
        } catch let error as RuuviServiceError {
            setLatestRecordSyncStatus(.onError, for: localCloudMacIds)
            if case .ruuviCloud(.api(.api(.erUnauthorized))) = error {
                self.postNotification()
            }
            throw error
        }
    }

    private func localCloudSensorMacIds() async -> [MACIdentifier] {
        (try? await ruuviStorage.readAll())?
            .filter(\.isCloud)
            .compactMap(\.macId) ?? []
    }

    private func setLatestRecordSyncStatus(
        _ status: NetworkSyncStatus,
        for macIds: [MACIdentifier]
    ) {
        macIds.forEach {
            ruuviLocalSyncState.setSyncStatusLatestRecord(status, for: $0)
        }
    }

    private func loadDenseSensors() async throws -> [RuuviCloudSensorDense] {
        try await RuuviServiceError.perform {
            try await self.ruuviCloud.loadSensorsDense(
                for: nil,
                measurements: true,
                sharedToOthers: true,
                sharedToMe: true,
                alerts: true,
                settings: true
            )
        }
    }

    private func syncAlerts(from denseSensors: [RuuviCloudSensorDense]) {
        alertService.sync(cloudAlerts: denseSensors.compactMap(\.alerts))
    }

    private func markNoHistorySensorsSynced(_ denseSensors: [RuuviCloudSensorDense]) {
        denseSensors
            .filter { ($0.subscription?.maxHistoryDays).map { $0 <= 0 } ?? false }
            .forEach { denseSensor in
                ruuviLocalSyncState.setSyncDate(
                    denseSensor.record?.date,
                    for: denseSensor.sensor.ruuviTagSensor.macId
                )
            }
    }

    private func updateLatestRecords(from denseSensors: [RuuviCloudSensorDense]) async throws {
        for denseSensor in denseSensors {
            _ = try await updateLatestRecord(
                ruuviTag: denseSensor.sensor.ruuviTagSensor,
                cloudRecord: denseSensor.record
            )
        }
    }

    private func addLatestRecordsToHistory(from denseSensors: [RuuviCloudSensorDense]) async throws {
        for denseSensor in denseSensors {
            _ = try await addLatestRecordToHistory(
                ruuviTag: denseSensor.sensor.ruuviTagSensor,
                cloudRecord: denseSensor.record,
                macId: denseSensor.sensor.id.mac
            )
        }
    }

    private var shouldSyncHistory: Bool {
        ruuviLocalSettings.historySyncLegacy || ruuviLocalSettings.historySyncOnDashboard
    }

    private func completeLocalSensorsMissingFromCloud(
        localCloudMacIds: [MACIdentifier],
        denseSensors: [RuuviCloudSensorDense]
    ) {
        let syncedMacValues = Set(
            denseSensors.compactMap { $0.sensor.ruuviTagSensor.macId?.value }
        )
        for macId in localCloudMacIds where !syncedMacValues.contains(macId.value) {
            ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: macId)
        }
    }

    private func syncSensors(
        cloudSensors: [AnyCloudSensor],
        denseSensor: [RuuviCloudSensorDense]
    ) async throws -> Set<AnyRuuviTagSensor> {
        return try await RuuviServiceError.perform {
            let localSensors = try await self.ruuviStorage.readAll()
            let inventoryResult = try await self.syncSensorInventory(
                localSensors: localSensors,
                cloudSensors: cloudSensors
            )

            self.queueCloudImageDownloads(
                cloudSensors: cloudSensors,
                skipping: inventoryResult.skipImageDownloadIds
            )

            try await self.subscriptionSyncs(
                cloudSensors: denseSensor
            )
            try await self.offsetSyncs(
                cloudSensors: cloudSensors,
                localSensors: localSensors,
                updatedSensors: inventoryResult.updatedSensors
            )
            try await self.displaySettingsSyncs(
                denseSensors: denseSensor
            )

            return inventoryResult.updatedSensors
        }
    }

    private func syncSensorInventory(
        localSensors: [AnyRuuviTagSensor],
        cloudSensors: [AnyCloudSensor]
    ) async throws -> SensorInventorySyncResult {
        var result = SensorInventorySyncResult()

        for localSensor in localSensors {
            let change: LocalSensorSyncChange
            if let cloudSensor = matchingCloudSensor(for: localSensor, in: cloudSensors) {
                change = try await syncExistingLocalSensor(localSensor, with: cloudSensor)
            } else {
                change = try await syncLocalSensorMissingFromCloud(localSensor)
            }

            if let updatedSensor = change.updatedSensor {
                result.updatedSensors.insert(updatedSensor)
            }
            if let skippedImageId = change.skipImageDownloadId {
                result.skipImageDownloadIds.insert(skippedImageId)
            }
        }

        let createdSensors = try await createMissingLocalSensors(
            cloudSensors: cloudSensors,
            localSensors: localSensors
        )
        result.updatedSensors.formUnion(createdSensors)
        return result
    }

    private func matchingCloudSensor(
        for localSensor: AnyRuuviTagSensor,
        in cloudSensors: [AnyCloudSensor]
    ) -> AnyCloudSensor? {
        cloudSensors.first {
            $0.id.isLast3BytesEqual(to: localSensor.id)
        }
    }

    private func syncExistingLocalSensor(
        _ localSensor: AnyRuuviTagSensor,
        with cloudSensor: AnyCloudSensor
    ) async throws -> LocalSensorSyncChange {
        let syncAction = SyncCollisionResolver.resolve(
            isOwner: localSensor.isOwner,
            localTimestamp: localSensor.lastUpdated,
            cloudTimestamp: cloudSensor.lastUpdated
        )

        switch syncAction {
        case .updateLocal:
            if shouldDownloadFullHistoryAfterPlanUpgrade(
                localSensor: localSensor,
                cloudSensor: cloudSensor
            ) {
                ruuviLocalSyncState.setDownloadFullHistory(
                    for: localSensor.macId,
                    downloadFull: true
                )
            }
            let updatedSensor = localSensor.with(cloudSensor: cloudSensor)
            _ = try await ruuviPool.update(updatedSensor)
            return LocalSensorSyncChange(updatedSensor: localSensor)

        case .keepLocalAndQueue:
            if let macId = localSensor.macId {
                queueSensorUpdateToCloud(localSensor, macId: macId)
            }
            queueSensorImageUpdateToCloud(
                localSensor: localSensor,
                cloudSensor: cloudSensor
            )
            return LocalSensorSyncChange(skipImageDownloadId: cloudSensor.id)

        case .noAction:
            return LocalSensorSyncChange()
        }
    }

    private func shouldDownloadFullHistoryAfterPlanUpgrade(
        localSensor: AnyRuuviTagSensor,
        cloudSensor: AnyCloudSensor
    ) -> Bool {
        localSensor.ownersPlan?.lowercased() == "free"
            && localSensor.ownersPlan?.lowercased() != cloudSensor.ownersPlan?.lowercased()
    }

    private func syncLocalSensorMissingFromCloud(
        _ localSensor: AnyRuuviTagSensor
    ) async throws -> LocalSensorSyncChange {
        let unclaimed = localSensor.unclaimed()
        if localSensor.isCloud {
            ruuviLocalSyncState.setDownloadFullHistory(
                for: localSensor.macId,
                downloadFull: nil
            )
            _ = try await ruuviPool.delete(localSensor)
            return LocalSensorSyncChange()
        } else if localSensor.isClaimed {
            _ = try await ruuviPool.update(unclaimed)
            return LocalSensorSyncChange(updatedSensor: localSensor)
        } else {
            return LocalSensorSyncChange()
        }
    }

    private func createMissingLocalSensors(
        cloudSensors: [AnyCloudSensor],
        localSensors: [AnyRuuviTagSensor]
    ) async throws -> Set<AnyRuuviTagSensor> {
        var createdSensors = Set<AnyRuuviTagSensor>()
        for cloudSensor in cloudSensors where isCloudSensorMissingLocally(
            cloudSensor,
            localSensors: localSensors
        ) {
            let newLocalSensor = cloudSensor.ruuviTagSensor
            createdSensors.insert(newLocalSensor.any)
            _ = try await ruuviPool.create(newLocalSensor)
        }
        return createdSensors
    }

    private func isCloudSensorMissingLocally(
        _ cloudSensor: AnyCloudSensor,
        localSensors: [AnyRuuviTagSensor]
    ) -> Bool {
        !localSensors.contains {
            $0.id.isLast3BytesEqual(to: cloudSensor.id)
        }
    }

    private func queueCloudImageDownloads(
        cloudSensors: [AnyCloudSensor],
        skipping skippedIds: Set<String>
    ) {
        let sensorsToDownload = cloudSensors.filter {
            !skippedIds.contains($0.id)
                && !ruuviLocalImages.isPictureCached(for: $0)
        }
        for cloudSensor in sensorsToDownload {
            Task {
                _ = try? await self.syncImage(sensor: cloudSensor)
            }
        }
    }

    // This method updates the latest data table if a record already exists for the mac address.
    // Otherwise it creates a new record.
    // swiftlint:disable:next function_body_length
    private func updateLatestRecord(
        ruuviTag: RuuviTagSensor,
        cloudRecord: RuuviTagSensorRecord?
    )
    async throws -> Bool {
        return try await RuuviServiceError.perform {
            guard let cloudRecord else {
                self.ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
                return false
            }

            if cloudRecord.version > 0 && cloudRecord.version != ruuviTag.version {
                Task {
                    _ = try? await self.ruuviPool.update(ruuviTag.with(version: cloudRecord.version))
                }
            }

            do {
                let record = try await self.ruuviStorage.readLatest(ruuviTag)

                if let record,
                   let localRecordMac = record.macId?.any,
                   localRecordMac == cloudRecord.macId?.any {
                   let isMeasurementNew = cloudRecord.date > record.date
                    if self.ruuviLocalSettings.cloudModeEnabled || isMeasurementNew {
                        let recordWithId = cloudRecord.with(macId: localRecordMac)
                        _ = try await self.ruuviPool.updateLast(recordWithId)
                        self.ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
                        return true
                    } else {
                        self.ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
                        return false
                    }
                } else {
                    _ = try await self.ruuviPool.createLast(cloudRecord)
                    self.ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
                    return true
                }
            } catch {
                self.ruuviLocalSyncState.setSyncStatusLatestRecord(.onError, for: ruuviTag.id.mac)
                throw error
            }
        }
    }

    /// This method writes the latest data point to the history/records table
    private func addLatestRecordToHistory(
        ruuviTag: RuuviTagSensor,
        cloudRecord: RuuviTagSensorRecord?,
        macId: MACIdentifier
    )
    async throws -> Bool {
        return try await RuuviServiceError.perform {
            guard let cloudRecord else {
                return false
            }

            do {
                let record = try await self.ruuviStorage.readLast(ruuviTag)
                let isMeasurementNew = record.map { cloudRecord.date > $0.date } ?? true

                if let localRecordMac = record?.macId?.any,
                   localRecordMac == cloudRecord.macId?.any {
                    let recordWithId = cloudRecord.with(macId: localRecordMac)
                    if self.ruuviLocalSettings.cloudModeEnabled || isMeasurementNew {
                        return try await self.createHistoryRecord(with: recordWithId)
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            } catch {
                let recordWithId = cloudRecord.with(macId: macId.any)
                return try await self.createHistoryRecord(with: recordWithId)
            }
        }
    }

    private func createHistoryRecord(
        with cloudRecord: RuuviTagSensorRecord
    ) async throws -> Bool {
        _ = try await RuuviServiceError.perform {
            try await self.ruuviPool.create(cloudRecord)
        }
        return true
    }

    @discardableResult
    public func syncQueuedRequest(request: RuuviCloudQueuedRequest) async throws -> Bool {
        do {
            let success = try await RuuviServiceError.perform {
            try await self.ruuviCloud.executeQueuedRequest(from: request)
            }
            _ = try? await self.ruuviPool.deleteQueuedRequest(request)
            return success
        } catch let error as RuuviServiceError {
            switch error {
            case .ruuviCloud(.api(.api(.erConflict))):
                // We should delete the request from local db when there's
                // already new data available on the cloud.
                _ = try? await self.ruuviPool.deleteQueuedRequest(request)
                throw error
            default:
                throw error
            }
        }
    }

    private func postNotification() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .NetworkSyncDidFailForAuthorization,
                object: nil,
                userInfo: nil
            )
        }
    }

    /// Queue local sensor update to cloud when local data is newer.
    /// This pushes local sensor name to cloud, which will handle offline queuing.
    private func queueSensorUpdateToCloud(_ sensor: RuuviTagSensor, macId: MACIdentifier) {
        Task {
            _ = try? await ruuviCloud.update(name: sensor.name, for: sensor)
        }
    }

    /// Queue local sensor background image update to cloud when local data is newer.
    /// If local has a custom image it is uploaded, otherwise cloud image is reset.
    private func queueSensorImageUpdateToCloud(
        localSensor: RuuviTagSensor,
        cloudSensor: CloudSensor
    ) {
        guard let macId = localSensor.macId else { return }

        if let localImage = localCustomBackground(for: localSensor) {
            // Local image already matches cloud cache URL; no action needed.
            if ruuviLocalImages.isPictureCached(for: cloudSensor) {
                return
            }

            guard let imageData = localImage.jpegData(compressionQuality: 1.0) else { return }
            Task {
                _ = try? await ruuviCloud.upload(
                    imageData: imageData,
                    mimeType: .jpg,
                    progress: nil,
                    for: macId
                )
            }
            return
        }

        // Local has no custom image; clear custom cloud image if cloud still has one.
        guard cloudSensor.picture != nil else { return }
        Task {
            try? await ruuviCloud.resetImage(for: macId)
        }
    }

    private func localCustomBackground(for sensor: RuuviTagSensor) -> UIImage? {
        if let macId = sensor.macId,
           let image = ruuviLocalImages.getCustomBackground(for: macId) {
            return image
        }

        if let luid = sensor.luid,
           let image = ruuviLocalImages.getCustomBackground(for: luid) {
            return image
        }

        return nil
    }

    /// Queue local display settings update to cloud when local data is newer.
    private func queueDisplaySettingsToCloud(
        sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        description: String?,
        includesDescription: Bool
    ) {
        guard sensor.isCloud else { return }

        var types: [String] = []
        var values: [String] = []

        if let defaultOrder = defaultDisplayOrder {
            types.append(RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue)
            values.append(defaultOrder ? "true" : "false")
        }

        if let displayOrder, !displayOrder.isEmpty {
            let encoded = String(data: try! JSONEncoder().encode(displayOrder), encoding: .utf8)!
            types.append(RuuviCloudApiSetting.sensorDisplayOrder.rawValue)
            values.append(encoded)
        }

        if includesDescription {
            types.append(RuuviCloudApiSetting.sensorDescription.rawValue)
            values.append(description ?? "")
        }

        guard !types.isEmpty else { return }

        Task {
            _ = try? await ruuviCloud.updateSensorSettings(
                for: sensor,
                types: types,
                values: values,
                timestamp: Int(Date().timeIntervalSince1970)
            )
        }
    }

    /// Queue local offset updates to cloud when local data is newer.
    private func queueOffsetUpdatesToCloud(
        sensor: RuuviTagSensor,
        settings: SensorSettings?
    ) {
        guard sensor.isCloud else { return }

        let temperatureOffset = settings?.temperatureOffset
        let humidityOffset = settings?.humidityOffset.map { $0 * 100 }
        let pressureOffset = settings?.pressureOffset.map { $0 * 100 }

        guard temperatureOffset != nil || humidityOffset != nil || pressureOffset != nil else {
            return
        }

        Task {
            _ = try? await ruuviCloud.update(
                temperatureOffset: temperatureOffset,
                humidityOffset: humidityOffset,
                pressureOffset: pressureOffset,
                for: sensor
            )
        }
    }
}
