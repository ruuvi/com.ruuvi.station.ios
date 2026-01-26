import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviRepository
import RuuviStorage
import UIKit
// swiftlint:disable file_length

// Actor for thread-safe tracking of ongoing history syncs
private actor OngoingHistorySyncsTracker {
    private var syncs: Set<AnyRuuviTagSensor> = []

    func contains(_ sensor: AnyRuuviTagSensor) -> Bool {
        syncs.contains(sensor)
    }

    func insert(_ sensor: AnyRuuviTagSensor) {
        syncs.insert(sensor)
    }

    func remove(_ sensor: AnyRuuviTagSensor) {
        syncs.remove(sensor)
    }
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

    // Actor for thread-safe tracking of ongoing history syncs
    private let ongoingHistorySyncs = OngoingHistorySyncsTracker()

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
        ruuviAppSettingsService: RuuviServiceAppSettings
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
    }

    @discardableResult
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func syncSettings() async throws -> RuuviCloudSettings {
        let cloudSettings: RuuviCloudSettings?
        do {
            cloudSettings = try await ruuviCloud.getCloudSettings()
        } catch let error as RuuviCloudError {
            if case .api(.api(.erUnauthorized)) = error {
                postNotification()
            }
            throw RuuviServiceError.ruuviCloud(error)
        }

        guard let cloudSettings else {
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
        if let cloudProfileLanguageCode = cloudSettings.profileLanguageCode {
            if cloudProfileLanguageCode != ruuviLocalSettings.cloudProfileLanguageCode {
                ruuviLocalSettings.cloudProfileLanguageCode = cloudProfileLanguageCode
            }
        } else {
            let languageCode = ruuviLocalSettings.language.rawValue
            Task { [ruuviAppSettingsService] in
                _ = try? await ruuviAppSettingsService.set(profileLanguageCode: languageCode)
            }
            ruuviLocalSettings.cloudProfileLanguageCode = languageCode
        }

        if let dashboardSensorOrderString = cloudSettings.dashboardSensorOrder,
           let dashboardSensorOrder = RuuviCloudApiHelper.jsonArrayFromString(dashboardSensorOrderString),
           dashboardSensorOrder != ruuviLocalSettings.dashboardSensorOrder {
            ruuviLocalSettings.dashboardSensorOrder = dashboardSensorOrder
        }

        return cloudSettings
    }

    @discardableResult
    public func syncImage(sensor: CloudSensor) async throws -> URL {
        guard let pictureUrl = sensor.picture
        else {
            throw RuuviServiceError.pictureUrlIsNil
        }

        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: pictureUrl)
        } catch {
            throw RuuviServiceError.networking(error)
        }
        guard let image = UIImage(data: data) else {
            throw RuuviServiceError.failedToParseNetworkResponse
        }
        do {
            let fileUrl = try await ruuviLocalImages.setCustomBackground(
                image: image,
                compressionQuality: 1.0,
                for: sensor.id.mac
            )
            ruuviLocalImages.setPictureIsCached(for: sensor)
            return fileUrl
        } catch let error as RuuviLocalError {
            throw RuuviServiceError.ruuviLocal(error)
        }
    }

    @discardableResult
    public func syncAll() async throws -> Set<AnyRuuviTagSensor> {
        _ = try await executePendingRequests()
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
        let requests: [RuuviCloudQueuedRequest]
        do {
            requests = try await ruuviStorage.readQueuedRequests()
        } catch let error as RuuviStorageError {
            throw RuuviServiceError.ruuviStorage(error)
        }

        guard !requests.isEmpty else {
            return true
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask {
                    _ = try await self.syncQueuedRequest(request: request)
                }
            }
            try await group.waitForAll()
        }

        return true
    }

    private func syncOffsets(
        cloudSensors: [AnyCloudSensor],
        updatedSensors: Set<AnyRuuviTagSensor>
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for cloudSensor in cloudSensors {
                guard let updatedSensor = updatedSensors.first(where: { $0.id == cloudSensor.id }) else {
                    continue
                }
                group.addTask {
                    _ = try await self.ruuviPool.updateOffsetCorrection(
                        type: .temperature,
                        with: cloudSensor.offsetTemperature,
                        of: updatedSensor
                    )
                }
                if let offsetHumidity = cloudSensor.offsetHumidity {
                    group.addTask {
                        _ = try await self.ruuviPool.updateOffsetCorrection(
                            type: .humidity,
                            with: offsetHumidity / 100,
                            of: updatedSensor
                        )
                    }
                }
                if let offsetPressure = cloudSensor.offsetPressure {
                    group.addTask {
                        _ = try await self.ruuviPool.updateOffsetCorrection(
                            type: .pressure,
                            with: offsetPressure / 100,
                            of: updatedSensor
                        )
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    private func syncDisplaySettings(
        denseSensors: [RuuviCloudSensorDense]
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for denseSensor in denseSensors {
                guard let sensorSettings = denseSensor.settings else {
                    continue
                }
                group.addTask {
                    _ = try await self.ruuviPool.updateDisplaySettings(
                        for: denseSensor.sensor.ruuviTagSensor,
                        displayOrder: sensorSettings.displayOrderCodes,
                        defaultDisplayOrder: sensorSettings.defaultDisplayOrder
                    )
                }
            }
            try await group.waitForAll()
        }
    }

    private func syncSubscriptions(
        cloudSensors: [RuuviCloudSensorDense],
        updatedSensors: Set<AnyRuuviTagSensor>
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for cloudSensor in cloudSensors {
                guard let updatedSensor = updatedSensors.first(where: { $0.id == cloudSensor.sensor.id }),
                      let macId = updatedSensor.macId?.mac,
                      let cloudSubscription = cloudSensor.subscription else {
                    continue
                }
                let subscription = cloudSubscription.with(macId: macId)
                group.addTask {
                    _ = try await self.ruuviPool.save(subscription: subscription)
                }
            }
            try await group.waitForAll()
        }
    }

    @discardableResult
    public func sync(sensor: RuuviTagSensor) async throws -> [AnyRuuviTagSensorRecord] {
        // Check if a history sync is already in progress for this sensor
        // and return early if so.
        if await ongoingHistorySyncs.contains(sensor.any) {
            return []
        }

        guard let maxHistoryDays = sensor.maxHistoryDays, maxHistoryDays > 0 else {
            return []
        }

        let networkPruningOffset = -TimeInterval(ruuviLocalSettings.networkPruningIntervalHours * 60 * 60)
        let networkPuningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let lastSynDate = ruuviLocalSyncState.getSyncDate(for: sensor.macId)

        let syncFullHistory = ruuviLocalSyncState.downloadFullHistory(for: sensor.macId) ?? false

        ruuviLocalSyncState.setSyncStatusHistory(.syncing, for: sensor.macId)
        await ongoingHistorySyncs.insert(sensor.any)

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
            ruuviLocalSyncState.setSyncStatusHistory(.none, for: sensor.macId)
            await ongoingHistorySyncs.remove(sensor.any)
            return result
        } catch {
            ruuviLocalSyncState.setSyncStatusHistory(.onError, for: sensor.macId)
            ruuviLocalSyncState.setSyncStatusHistory(.none, for: sensor.macId)
            await ongoingHistorySyncs.remove(sensor.any)
            throw error
        }
    }

    @discardableResult
    public func syncAllHistory() async throws -> Bool {
        let localSensors: [AnyRuuviTagSensor]
        do {
            localSensors = try await ruuviStorage.readAll()
        } catch let error as RuuviStorageError {
            throw RuuviServiceError.ruuviStorage(error)
        }

        let sensorsToCheck = localSensors.filter { sensor in
            guard sensor.isCloud,
                  let maxHistoryDays = sensor.maxHistoryDays,
                  maxHistoryDays > 0 else {
                return false
            }
            return true
        }

        let sensorRecords: [(AnyRuuviTagSensor, RuuviTagSensorRecord?)] = try await withThrowingTaskGroup(
            of: (AnyRuuviTagSensor, RuuviTagSensorRecord?).self
        ) { group in
            for sensor in sensorsToCheck {
                group.addTask {
                    do {
                        let record = try await self.ruuviStorage.readLatest(sensor)
                        return (sensor, record)
                    } catch let error as RuuviStorageError {
                        throw RuuviServiceError.ruuviStorage(error)
                    }
                }
            }
            var results: [(AnyRuuviTagSensor, RuuviTagSensorRecord?)] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }

        let sensorsToSync = sensorRecords
            .filter { $0.1 != nil }
            .map { $0.0 }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for sensor in sensorsToSync {
                group.addTask {
                    _ = try await self.sync(sensor: sensor)
                }
            }
            try await group.waitForAll()
        }

        return true
    }

    private lazy var syncRecordsLoader: RuuviCloudSyncRecordsLoader = {
        RuuviCloudSyncRecordsLoader(
            ruuviCloud: ruuviCloud,
            ruuviRepository: ruuviRepository,
            ruuviLocalIDs: ruuviLocalIDs
        )
    }()

    private func syncRecordsOperation(
        for sensor: RuuviTagSensor,
        since: Date
    ) async throws -> [AnyRuuviTagSensorRecord] {
        try await syncRecordsLoader.loadRecords(
            sensor: sensor,
            since: since
        )
    }

    // This method syncs the sensors, latest measurements and alerts.
    // swiftlint:disable:next function_body_length
    private func syncSensors() async throws -> Set<AnyRuuviTagSensor> {
        let localSensors: [AnyRuuviTagSensor]
        do {
            localSensors = try await ruuviStorage.readAll()
        } catch let error as RuuviStorageError {
            throw RuuviServiceError.ruuviStorage(error)
        }

        // Set cloud sensors in syncing state
        // Skip the sensors if not claimed or cloud sensors
        for sensor in localSensors {
            if let macId = sensor.macId, sensor.isCloud {
                ruuviLocalSyncState.setSyncStatusLatestRecord(.syncing, for: macId)
            }
        }

        // Fetch data from the dense endpoint
        let denseSensors: [RuuviCloudSensorDense]
        do {
            denseSensors = try await ruuviCloud.loadSensorsDense(
                for: nil,
                measurements: true,
                sharedToOthers: true,
                sharedToMe: true,
                alerts: true,
                settings: true
            )
        } catch let error as RuuviCloudError {
            if case .api(.api(.erUnauthorized)) = error {
                postNotification()
            }
            throw RuuviServiceError.ruuviCloud(error)
        }

        let alerts = denseSensors.map { $0.alerts }
        await alertService.sync(cloudAlerts: alerts)

        let cloudSensors = denseSensors.map { $0.sensor.any }
        let updatedSensors = try await syncSensors(
            cloudSensors: cloudSensors,
            denseSensor: denseSensors
        )

        let filteredDenseSensorsWithoutHistory = denseSensors.filter { sensor in
            guard let maxHistoryDays = sensor.subscription?.maxHistoryDays else {
                return false
            }
            return maxHistoryDays <= 0
        }

        // Store the latest measurement record date for the sensors without history
        // as the sync date. For the rest this value will be set after successful sync.
        filteredDenseSensorsWithoutHistory.forEach { ruuviTag in
            ruuviLocalSyncState.setSyncDate(
                ruuviTag.record?.date,
                for: ruuviTag.sensor.ruuviTagSensor.macId
            )
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for sensor in denseSensors {
                group.addTask {
                    _ = try await self.updateLatestRecord(
                        ruuviTag: sensor.sensor.ruuviTagSensor,
                        cloudRecord: sensor.record
                    )
                }
            }
            try await group.waitForAll()
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for sensor in denseSensors {
                group.addTask {
                    _ = try await self.addLatestRecordToHistory(
                        ruuviTag: sensor.sensor.ruuviTagSensor,
                        cloudRecord: sensor.record
                    )
                }
            }
            try await group.waitForAll()
        }

        if ruuviLocalSettings.historySyncLegacy || ruuviLocalSettings.historySyncOnDashboard {
            _ = try await syncAllHistory()
        }

        return updatedSensors
    }

    // swiftlint:disable:next function_body_length
    private func syncSensors(
        cloudSensors: [AnyCloudSensor],
        denseSensor: [RuuviCloudSensorDense]
    ) async throws -> Set<AnyRuuviTagSensor> {
        var updatedSensors = Set<AnyRuuviTagSensor>()
        let localSensors: [AnyRuuviTagSensor]
        do {
            localSensors = try await ruuviStorage.readAll()
        } catch let error as RuuviStorageError {
            throw RuuviServiceError.ruuviStorage(error)
        }

        var operations: [() async throws -> Bool] = []
        for localSensor in localSensors {
            if let cloudSensor = cloudSensors.first(where: {
                $0.id.isLast3BytesEqual(to: localSensor.id)
            }) {
                updatedSensors.insert(localSensor)
                // Update the local sensor data with cloud data
                // if there's a match of sensor in local storage and cloud
                // TODO: @priyonto - Need to improve this once backend flattens and improves the plans
                // If user goes from free to pro or above plan, download full history
                if localSensor.ownersPlan?.lowercased() == "free",
                   localSensor.ownersPlan?.lowercased() != cloudSensor.ownersPlan?.lowercased() {
                    ruuviLocalSyncState.setDownloadFullHistory(
                        for: localSensor.macId,
                        downloadFull: true
                    )
                }
                operations.append {
                    try await self.ruuviPool.update(localSensor.with(cloudSensor: cloudSensor))
                }
            } else {
                let unclaimed = localSensor.unclaimed()
                // If there is a local sensor which is unclaimed insert it to the list
                if unclaimed.any != localSensor {
                    updatedSensors.insert(localSensor)
                    operations.append {
                        try await self.ruuviPool.update(unclaimed)
                    }
                } else {
                    // If there is a local sensor which is claimed and deleted from the cloud,
                    // delete it from local storage
                    // Otherwise keep it stored
                    if localSensor.isCloud {
                        ruuviLocalSyncState.setDownloadFullHistory(
                            for: localSensor.macId,
                            downloadFull: nil
                        )
                        operations.append {
                            try await self.ruuviPool.delete(localSensor)
                        }
                    }
                }
            }
        }

        for newCloudSensor in cloudSensors
            .filter({ cloudSensor in
                !localSensors.contains(where: {
                    $0.id.isLast3BytesEqual(to: cloudSensor.id)
                })
            }) {
            let newLocalSensor = newCloudSensor.ruuviTagSensor
            updatedSensors.insert(newLocalSensor.any)
            operations.append {
                try await self.ruuviPool.create(newLocalSensor)
            }
        }

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for operation in operations {
                    group.addTask {
                        _ = try await operation()
                    }
                }
                try await group.waitForAll()
            }
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        }

        for cloudSensor in cloudSensors where !ruuviLocalImages.isPictureCached(for: cloudSensor) {
            Task { [weak self] in
                _ = try? await self?.syncImage(sensor: cloudSensor)
            }
        }

        do {
            try await syncSubscriptions(cloudSensors: denseSensor, updatedSensors: updatedSensors)
            try await syncOffsets(cloudSensors: cloudSensors, updatedSensors: updatedSensors)
            try await syncDisplaySettings(denseSensors: denseSensor)
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        }

        return updatedSensors
    }

    // This method updates the latest data table if a record already exists for the mac address.
    // Otherwise it creates a new record.
    // swiftlint:disable:next function_body_length
    private func updateLatestRecord(
        ruuviTag: RuuviTagSensor,
        cloudRecord: RuuviTagSensorRecord?
    )
    async throws -> Bool {
        guard let cloudRecord else {
            // If there's no cloud record return
            // It is possible that a sensor doesn't have a record if it's a few years old
            ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
            return false
        }

        // First update the version number of the tag if there is a difference between
        // cloud data and local data.
        if cloudRecord.version > 0 && cloudRecord.version != ruuviTag.version {
            Task { [ruuviPool] in
                _ = try? await ruuviPool.update(ruuviTag.with(version: cloudRecord.version))
            }
        }

        do {
            let record = try await ruuviStorage.readLatest(ruuviTag)
            // If the latest table already have a data point for the mac update that record
            if let record, record.macId != nil,
               record.macId?.any == cloudRecord.macId?.any {
                // Store cloud point only if the cloud data is newer than the local data
                let isMeasurementNew = cloudRecord.date > record.date
                if ruuviLocalSettings.cloudModeEnabled || isMeasurementNew {
                    let recordWithId = cloudRecord.with(macId: record.macId!.any)
                    do {
                        _ = try await ruuviPool.updateLast(recordWithId)
                        ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
                        return true
                    } catch let error as RuuviPoolError {
                        ruuviLocalSyncState.setSyncStatusLatestRecord(.onError, for: ruuviTag.id.mac)
                        throw RuuviServiceError.ruuviPool(error)
                    }
                } else {
                    ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
                    return false
                }
            } else {
                // If no record found, create a new record
                do {
                    _ = try await ruuviPool.createLast(cloudRecord)
                    ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
                    return true
                } catch let error as RuuviPoolError {
                    ruuviLocalSyncState.setSyncStatusLatestRecord(.onError, for: ruuviTag.id.mac)
                    throw RuuviServiceError.ruuviPool(error)
                }
            }
        } catch let error as RuuviStorageError {
            ruuviLocalSyncState.setSyncStatusLatestRecord(.onError, for: ruuviTag.id.mac)
            throw RuuviServiceError.ruuviStorage(error)
        }
    }

    /// This method writes the latest data point to the history/records table
    private func addLatestRecordToHistory(
        ruuviTag: RuuviTagSensor,
        cloudRecord: RuuviTagSensorRecord?
    )
    async throws -> Bool {
        guard let cloudRecord else {
            // If there's no cloud record return
            // It is possible that a sensor doesn't have a record if it's a few years old
            return false
        }

        do {
            let record = try await ruuviStorage.readLast(ruuviTag)
            let isMeasurementNew = record.map { cloudRecord.date > $0.date } ?? true
            if let localRecordMac = record?.macId?.any,
               localRecordMac == cloudRecord.macId?.any {
                let recordWithId = cloudRecord.with(macId: localRecordMac)
                if ruuviLocalSettings.cloudModeEnabled || isMeasurementNew {
                    return try await createRecord(recordWithId)
                }
                return false
            }
            return false
        } catch {
            let recordWithId: RuuviTagSensorRecord
            if let macId = ruuviTag.macId {
                recordWithId = cloudRecord.with(macId: macId.any)
            } else {
                recordWithId = cloudRecord
            }
            return try await createRecord(recordWithId)
        }
    }

    private func createRecord(
        _ cloudRecord: RuuviTagSensorRecord
    ) async throws -> Bool {
        do {
            _ = try await ruuviPool.create(cloudRecord)
            return true
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        }
    }

    @discardableResult
    public func syncQueuedRequest(request: RuuviCloudQueuedRequest) async throws -> Bool {
        do {
            let success = try await ruuviCloud.executeQueuedRequest(from: request)
            _ = try? await ruuviPool.deleteQueuedRequest(request)
            return success
        } catch let error as RuuviCloudError {
            if case .api(.api(.erConflict)) = error {
                // We should delete the request from local db when there's
                // already new data available on the cloud.
                _ = try? await ruuviPool.deleteQueuedRequest(request)
            }
            throw RuuviServiceError.ruuviCloud(error)
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
}
