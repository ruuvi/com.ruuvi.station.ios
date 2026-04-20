import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviRepository
import RuuviStorage
import UIKit
// swiftlint:disable file_length
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

    // swiftlint:disable:next function_body_length
    private func offsetSyncs(
        cloudSensors: [CloudSensor],
        localSensors: [AnyRuuviTagSensor],
        updatedSensors: Set<AnyRuuviTagSensor>
    ) async throws {
        let sensorPairs = cloudSensors.compactMap { cloudSensor in
            let matchedSensor = updatedSensors.first {
                cloudSensor.id.isLast3BytesEqual(to: $0.id)
            } ?? localSensors.first {
                cloudSensor.id.isLast3BytesEqual(to: $0.id)
            }
            return matchedSensor.map { (cloudSensor, $0) }
        }

        for (cloudSensor, sensor) in sensorPairs {
            _ = try await RuuviServiceError.perform {
                let localSettings = try? await self.ruuviStorage.readSensorSettings(sensor)
                let fallbackSettings = localSettings ?? SensorSettingsStruct(
                    luid: sensor.luid,
                    macId: sensor.macId,
                    temperatureOffset: nil,
                    humidityOffset: nil,
                    pressureOffset: nil
                )

                let syncAction = SyncCollisionResolver.resolve(
                    isOwner: sensor.isOwner,
                    localTimestamp: sensor.lastUpdated,
                    cloudTimestamp: cloudSensor.lastUpdated
                )

                switch syncAction {
                case .updateLocal:
                    var lastUpdatedSettings: SensorSettings = fallbackSettings

                    if cloudSensor.offsetTemperature != localSettings?.temperatureOffset {
                        lastUpdatedSettings = try await self.ruuviPool.updateOffsetCorrection(
                            type: .temperature,
                            with: cloudSensor.offsetTemperature,
                            of: sensor
                        )
                    }

                    if let offsetHumidity = cloudSensor.offsetHumidity {
                        let newHumidityOffset = offsetHumidity / 100
                        if newHumidityOffset != localSettings?.humidityOffset {
                            lastUpdatedSettings = try await self.ruuviPool.updateOffsetCorrection(
                                type: .humidity,
                                with: newHumidityOffset,
                                of: sensor
                            )
                        }
                    }

                    if let offsetPressure = cloudSensor.offsetPressure {
                        let newPressureOffset = offsetPressure / 100
                        if newPressureOffset != localSettings?.pressureOffset {
                            lastUpdatedSettings = try await self.ruuviPool.updateOffsetCorrection(
                                type: .pressure,
                                with: newPressureOffset,
                                of: sensor
                            )
                        }
                    }

                    return lastUpdatedSettings

                case .keepLocalAndQueue:
                    var queuedTemperatureOffset: Double? = fallbackSettings.temperatureOffset
                    var queuedHumidityOffset: Double? = fallbackSettings.humidityOffset
                    var queuedPressureOffset: Double? = fallbackSettings.pressureOffset

                    if let localTempOffset = fallbackSettings.temperatureOffset,
                       let cloudTempOffset = cloudSensor.offsetTemperature,
                       localTempOffset == cloudTempOffset {
                        queuedTemperatureOffset = nil
                    }

                    if let localHumidityOffset = fallbackSettings.humidityOffset,
                       let cloudHumidityRaw = cloudSensor.offsetHumidity {
                        let cloudHumidityOffset = cloudHumidityRaw / 100
                        if localHumidityOffset == cloudHumidityOffset {
                            queuedHumidityOffset = nil
                        }
                    }

                    if let localPressureOffset = fallbackSettings.pressureOffset,
                       let cloudPressureRaw = cloudSensor.offsetPressure {
                        let cloudPressureOffset = cloudPressureRaw / 100
                        if localPressureOffset == cloudPressureOffset {
                            queuedPressureOffset = nil
                        }
                    }

                    let diffSettings = SensorSettingsStruct(
                        luid: fallbackSettings.luid,
                        macId: fallbackSettings.macId,
                        temperatureOffset: queuedTemperatureOffset,
                        humidityOffset: queuedHumidityOffset,
                        pressureOffset: queuedPressureOffset
                    )

                    self.queueOffsetUpdatesToCloud(
                        sensor: sensor,
                        settings: diffSettings
                    )
                    return fallbackSettings

                case .noAction:
                    return fallbackSettings
                }
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func displaySettingsSyncs(
        denseSensors: [RuuviCloudSensorDense]
    ) async throws {
        for denseSensor in denseSensors {
            guard let sensorSettings = denseSensor.settings else {
                continue
            }

            let sensor = denseSensor.sensor.ruuviTagSensor
            _ = try await RuuviServiceError.perform {
                let localSettings = try? await self.ruuviStorage.readSensorSettings(sensor)
                let fallbackSettings = localSettings ?? SensorSettingsStruct(
                    luid: sensor.luid,
                    macId: sensor.macId,
                    temperatureOffset: nil,
                    humidityOffset: nil,
                    pressureOffset: nil
                )

                let displayOrderAction = SyncCollisionResolver.resolve(
                    isOwner: denseSensor.sensor.isOwner,
                    localTimestamp: localSettings?.displayOrderLastUpdated,
                    cloudTimestamp: sensorSettings.displayOrderLastUpdated
                )

                let defaultOrderAction = SyncCollisionResolver.resolve(
                    isOwner: denseSensor.sensor.isOwner,
                    localTimestamp: localSettings?.defaultDisplayOrderLastUpdated,
                    cloudTimestamp: sensorSettings.defaultDisplayOrderLastUpdated
                )

                let descriptionAction = SyncCollisionResolver.resolve(
                    isOwner: denseSensor.sensor.isOwner,
                    localTimestamp: localSettings?.descriptionLastUpdated,
                    cloudTimestamp: sensorSettings.descriptionLastUpdated
                )

                let queueDisplayOrder = displayOrderAction == .keepLocalAndQueue
                    ? localSettings?.displayOrder
                    : nil
                let queueDefaultDisplayOrder = defaultOrderAction == .keepLocalAndQueue
                    ? localSettings?.defaultDisplayOrder
                    : nil
                let shouldQueueDescription = descriptionAction == .keepLocalAndQueue
                let queueDescription = shouldQueueDescription
                    ? localSettings?.description
                    : nil

                if queueDisplayOrder != nil || queueDefaultDisplayOrder != nil || shouldQueueDescription {
                    self.queueDisplaySettingsToCloud(
                        sensor: sensor,
                        displayOrder: queueDisplayOrder,
                        defaultDisplayOrder: queueDefaultDisplayOrder,
                        description: queueDescription,
                        includesDescription: shouldQueueDescription
                    )
                }

                guard displayOrderAction == .updateLocal
                    || defaultOrderAction == .updateLocal
                    || descriptionAction == .updateLocal else {
                    return fallbackSettings
                }

                let resolvedDisplayOrder = displayOrderAction == .updateLocal
                    ? sensorSettings.displayOrderCodes
                    : localSettings?.displayOrder
                let resolvedDisplayOrderLastUpdated = displayOrderAction == .updateLocal
                    ? sensorSettings.displayOrderLastUpdated
                    : localSettings?.displayOrderLastUpdated
                let resolvedDefaultDisplayOrder = defaultOrderAction == .updateLocal
                    ? sensorSettings.defaultDisplayOrder
                    : localSettings?.defaultDisplayOrder
                let resolvedDefaultDisplayOrderLastUpdated = defaultOrderAction == .updateLocal
                    ? sensorSettings.defaultDisplayOrderLastUpdated
                    : localSettings?.defaultDisplayOrderLastUpdated
                let resolvedDescription = descriptionAction == .updateLocal
                    ? sensorSettings.description
                    : localSettings?.description
                let resolvedDescriptionLastUpdated = descriptionAction == .updateLocal
                    ? sensorSettings.descriptionLastUpdated
                    : localSettings?.descriptionLastUpdated

                var lastUpdatedSettings: SensorSettings = fallbackSettings

                if displayOrderAction == .updateLocal || defaultOrderAction == .updateLocal {
                    lastUpdatedSettings = try await self.ruuviPool.updateDisplaySettings(
                        for: sensor,
                        displayOrder: resolvedDisplayOrder,
                        defaultDisplayOrder: resolvedDefaultDisplayOrder,
                        displayOrderLastUpdated: resolvedDisplayOrderLastUpdated,
                        defaultDisplayOrderLastUpdated: resolvedDefaultDisplayOrderLastUpdated
                    )
                }

                if descriptionAction == .updateLocal {
                    lastUpdatedSettings = try await self.ruuviPool.updateDescription(
                        for: sensor,
                        description: resolvedDescription,
                        descriptionLastUpdated: resolvedDescriptionLastUpdated
                    )
                }

                return lastUpdatedSettings
            }
        }
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
    // swiftlint:disable:next function_body_length
    private func syncSensors() async throws -> Set<AnyRuuviTagSensor> {
        let localCloudMacIds = (try? await self.ruuviStorage.readAll())?
            .filter(\.isCloud)
            .compactMap(\.macId) ?? []

        for macId in localCloudMacIds {
            self.ruuviLocalSyncState.setSyncStatusLatestRecord(.syncing, for: macId)
        }

        do {
            let denseSensors = try await RuuviServiceError.perform {
                try await self.ruuviCloud.loadSensorsDense(
                    for: nil,
                    measurements: true,
                    sharedToOthers: true,
                    sharedToMe: true,
                    alerts: true,
                    settings: true
                )
            }

            let alerts = denseSensors.compactMap(\.alerts)
            self.alertService.sync(cloudAlerts: alerts)

            let cloudSensors = denseSensors.compactMap { sensor in
                sensor.sensor.any
            }
            let updatedSensors = try await self.syncSensors(
                cloudSensors: cloudSensors,
                denseSensor: denseSensors
            )

            let filteredDenseSensorsWithoutHistory = denseSensors.filter { sensor in
                guard let maxHistoryDays = sensor.subscription?.maxHistoryDays else {
                    return false
                }
                return maxHistoryDays <= 0
            }

            filteredDenseSensorsWithoutHistory.forEach { [weak self] ruuviTag in
                self?.ruuviLocalSyncState.setSyncDate(
                    ruuviTag.record?.date,
                    for: ruuviTag.sensor.ruuviTagSensor.macId
                )
            }

            for denseSensor in denseSensors {
                _ = try await self.updateLatestRecord(
                    ruuviTag: denseSensor.sensor.ruuviTagSensor,
                    cloudRecord: denseSensor.record
                )
            }

            for denseSensor in denseSensors {
                _ = try await self.addLatestRecordToHistory(
                    ruuviTag: denseSensor.sensor.ruuviTagSensor,
                    cloudRecord: denseSensor.record,
                    macId: denseSensor.sensor.id.mac
                )
            }

            if self.ruuviLocalSettings.historySyncLegacy
                || self.ruuviLocalSettings.historySyncOnDashboard {
                _ = try await self.syncAllHistory()
            }

            let syncedMacValues = Set(
                denseSensors.compactMap { $0.sensor.ruuviTagSensor.macId?.value }
            )
            for macId in localCloudMacIds where !syncedMacValues.contains(macId.value) {
                self.ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: macId)
            }

            return updatedSensors
        } catch let error as RuuviServiceError {
            for macId in localCloudMacIds {
                self.ruuviLocalSyncState.setSyncStatusLatestRecord(.onError, for: macId)
            }
            if case .ruuviCloud(.api(.api(.erUnauthorized))) = error {
                self.postNotification()
            }
            throw error
        }
    }

    // swiftlint:disable:next function_body_length
    private func syncSensors(
        cloudSensors: [AnyCloudSensor],
        denseSensor: [RuuviCloudSensorDense]
    ) async throws -> Set<AnyRuuviTagSensor> {
        return try await RuuviServiceError.perform {
            let localSensors = try await self.ruuviStorage.readAll()
            var updatedSensors = Set<AnyRuuviTagSensor>()
            var skipCloudImageDownloadForSensorIDs = Set<String>()

            for localSensor in localSensors {
                if let cloudSensor = cloudSensors.first(where: {
                    $0.id.isLast3BytesEqual(to: localSensor.id)
                }) {
                    let syncAction = SyncCollisionResolver.resolve(
                        isOwner: localSensor.isOwner,
                        localTimestamp: localSensor.lastUpdated,
                        cloudTimestamp: cloudSensor.lastUpdated
                    )

                    switch syncAction {
                    case .updateLocal:
                        updatedSensors.insert(localSensor)
                        if localSensor.ownersPlan?.lowercased() == "free",
                           localSensor.ownersPlan?.lowercased() != cloudSensor.ownersPlan?.lowercased() {
                            self.ruuviLocalSyncState.setDownloadFullHistory(
                                for: localSensor.macId,
                                downloadFull: true
                            )
                        }
                        let updatedSensor = localSensor.with(cloudSensor: cloudSensor)
                        _ = try await self.ruuviPool.update(updatedSensor)

                    case .keepLocalAndQueue:
                        skipCloudImageDownloadForSensorIDs.insert(cloudSensor.id)
                        if let macId = localSensor.macId {
                            self.queueSensorUpdateToCloud(localSensor, macId: macId)
                        }
                        self.queueSensorImageUpdateToCloud(
                            localSensor: localSensor,
                            cloudSensor: cloudSensor
                        )

                    case .noAction:
                        break
                    }
                } else {
                    let unclaimed = localSensor.unclaimed()
                    if localSensor.isCloud {
                        self.ruuviLocalSyncState.setDownloadFullHistory(
                            for: localSensor.macId,
                            downloadFull: nil
                        )
                        _ = try await self.ruuviPool.delete(localSensor)
                    } else if localSensor.isClaimed {
                        updatedSensors.insert(localSensor)
                        _ = try await self.ruuviPool.update(unclaimed)
                    }
                }
            }

            for newCloudSensor in cloudSensors where !localSensors.contains(where: {
                $0.id.isLast3BytesEqual(to: newCloudSensor.id)
            }) {
                let newLocalSensor = newCloudSensor.ruuviTagSensor
                updatedSensors.insert(newLocalSensor.any)
                _ = try await self.ruuviPool.create(newLocalSensor)
            }

            let syncImages = cloudSensors
                .filter {
                    !skipCloudImageDownloadForSensorIDs.contains($0.id)
                        && !self.ruuviLocalImages.isPictureCached(for: $0)
                }
            if !syncImages.isEmpty {
                for cloudSensor in syncImages {
                    Task {
                        _ = try? await self.syncImage(sensor: cloudSensor)
                    }
                }
            }

            try await self.subscriptionSyncs(
                cloudSensors: denseSensor
            )
            try await self.offsetSyncs(
                cloudSensors: cloudSensors,
                localSensors: localSensors,
                updatedSensors: updatedSensors
            )
            try await self.displaySettingsSyncs(
                denseSensors: denseSensor
            )

            return updatedSensors
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
