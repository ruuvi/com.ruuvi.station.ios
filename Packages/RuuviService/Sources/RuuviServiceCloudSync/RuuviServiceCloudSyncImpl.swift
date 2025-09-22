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
        do {
            guard let cloudSettings = try await ruuviCloud.getCloudSettings() else {
                // No settings returned from cloud; propagate as unauthorized/empty state
                throw RuuviServiceError.ruuviCloud(.notAuthorized)
            }
            let sSelf = self
            if let unitTemperature = cloudSettings.unitTemperature,
               unitTemperature != sSelf.ruuviLocalSettings.temperatureUnit {
                sSelf.ruuviLocalSettings.temperatureUnit = unitTemperature
            }
            if let accuracyTemperature = cloudSettings.accuracyTemperature,
               accuracyTemperature != sSelf.ruuviLocalSettings.temperatureAccuracy {
                sSelf.ruuviLocalSettings.temperatureAccuracy = accuracyTemperature
            }
            if let unitHumidity = cloudSettings.unitHumidity,
               unitHumidity != sSelf.ruuviLocalSettings.humidityUnit {
                sSelf.ruuviLocalSettings.humidityUnit = unitHumidity
            }
            if let accuracyHumidity = cloudSettings.accuracyHumidity,
               accuracyHumidity != sSelf.ruuviLocalSettings.humidityAccuracy {
                sSelf.ruuviLocalSettings.humidityAccuracy = accuracyHumidity
            }
            if let unitPressure = cloudSettings.unitPressure,
               unitPressure != sSelf.ruuviLocalSettings.pressureUnit {
                sSelf.ruuviLocalSettings.pressureUnit = unitPressure
            }
            if let accuracyPressure = cloudSettings.accuracyPressure,
               accuracyPressure != sSelf.ruuviLocalSettings.pressureAccuracy {
                sSelf.ruuviLocalSettings.pressureAccuracy = accuracyPressure
            }
            if let chartShowAllData = cloudSettings.chartShowAllPoints,
               chartShowAllData != !sSelf.ruuviLocalSettings.chartDownsamplingOn {
                sSelf.ruuviLocalSettings.chartDownsamplingOn = !chartShowAllData
            }
            if let chartDrawDots = cloudSettings.chartDrawDots,
               chartDrawDots != sSelf.ruuviLocalSettings.chartDrawDotsOn {
                sSelf.ruuviLocalSettings.chartDrawDotsOn = false
            }
            if let chartShowMinMaxAvg = cloudSettings.chartShowMinMaxAvg,
               chartShowMinMaxAvg != sSelf.ruuviLocalSettings.chartStatsOn {
                sSelf.ruuviLocalSettings.chartStatsOn = chartShowMinMaxAvg
            }
            if let cloudModeEnabled = cloudSettings.cloudModeEnabled,
               cloudModeEnabled != sSelf.ruuviLocalSettings.cloudModeEnabled {
                sSelf.ruuviLocalSettings.cloudModeEnabled = cloudModeEnabled
            }
            if let dashboardEnabled = cloudSettings.dashboardEnabled,
               dashboardEnabled != sSelf.ruuviLocalSettings.dashboardEnabled {
                sSelf.ruuviLocalSettings.dashboardEnabled = dashboardEnabled
            }
            if let dashboardType = cloudSettings.dashboardType,
               dashboardType != sSelf.ruuviLocalSettings.dashboardType {
                sSelf.ruuviLocalSettings.dashboardType = dashboardType
            }
            if let dashboardTapActionType = cloudSettings.dashboardTapActionType,
               dashboardTapActionType != sSelf.ruuviLocalSettings.dashboardTapActionType {
                sSelf.ruuviLocalSettings.dashboardTapActionType = dashboardTapActionType
            }
            if let pushAlertDisabled = cloudSettings.pushAlertDisabled,
               pushAlertDisabled != sSelf.ruuviLocalSettings.pushAlertDisabled {
                sSelf.ruuviLocalSettings.pushAlertDisabled = pushAlertDisabled
            }
            if let emailAlertDisabled = cloudSettings.emailAlertDisabled,
               emailAlertDisabled != sSelf.ruuviLocalSettings.emailAlertDisabled {
                sSelf.ruuviLocalSettings.emailAlertDisabled = emailAlertDisabled
            }
            if let cloudProfileLanguageCode = cloudSettings.profileLanguageCode {
                if cloudProfileLanguageCode != sSelf.ruuviLocalSettings.cloudProfileLanguageCode {
                    sSelf.ruuviLocalSettings.cloudProfileLanguageCode = cloudProfileLanguageCode
                }
            } else {
                let languageCode = sSelf.ruuviLocalSettings.language.rawValue
                try await sSelf.ruuviAppSettingsService
                    .set(profileLanguageCode: languageCode)
                sSelf.ruuviLocalSettings.cloudProfileLanguageCode = languageCode
            }
            if let dashboardSensorOrderString = cloudSettings.dashboardSensorOrder,
               let dashboardSensorOrder = RuuviCloudApiHelper.jsonArrayFromString(dashboardSensorOrderString),
               dashboardSensorOrder != sSelf.ruuviLocalSettings.dashboardSensorOrder {
                sSelf.ruuviLocalSettings.dashboardSensorOrder = dashboardSensorOrder
            }
            return cloudSettings
        } catch let error as RuuviCloudError {
            switch error {
            case .api(.api(.erUnauthorized)):
                postNotification()
            default:
                throw RuuviServiceError.ruuviCloud(error)
            }
            // If unauthorized we already posted notification; propagate error as service error
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func syncImage(sensor: CloudSensor) async throws -> URL {
        guard let pictureUrl = sensor.picture else { throw RuuviServiceError.pictureUrlIsNil }
        do {
            let (data, _) = try await URLSession.shared.data(from: pictureUrl)
            guard let image = UIImage(data: data) else { throw RuuviServiceError.failedToParseNetworkResponse }
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
        } catch {
            throw RuuviServiceError.networking(error)
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
        defer { ruuviLocalSyncState.setSyncStatus(.none) }
        do {
            _ = try await syncSensors()
            ruuviLocalSyncState.setSyncStatus(.complete)
            ruuviLocalSyncState.setSyncDate(Date())
            return true
        } catch let error as RuuviServiceError {
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
        } catch let error as RuuviServiceError {
            ruuviLocalSyncState.setSyncStatus(.onError)
            throw error
        }
    }

    public func executePendingRequests() async throws -> Bool {
        do {
            let requests = try await ruuviStorage.readQueuedRequests()
            guard requests.count > 0 else { return true }
            for request in requests {
                _ = try await syncQueuedRequest(request: request)
            }
            return true
        } catch let error as RuuviStorageError {
            throw RuuviServiceError.ruuviStorage(error)
        }
    }

    private func offsetSyncs(
        cloudSensors: [CloudSensor],
        updatedSensors: Set<AnyRuuviTagSensor>
    ) async {
        for cloudSensor in cloudSensors {
            guard let updatedSensor = updatedSensors.first(where: { $0.id == cloudSensor.id }) else { continue }
            if let temperature = cloudSensor.offsetTemperature {
                _ = try? await ruuviPool.updateOffsetCorrection(
                    type: .temperature,
                    with: temperature,
                    of: updatedSensor
                )
            }
            if let offsetHumidity = cloudSensor.offsetHumidity {
                _ = try? await ruuviPool.updateOffsetCorrection(
                    type: .humidity,
                    with: offsetHumidity / 100,
                    of: updatedSensor
                )
            }
            if let offsetPressure = cloudSensor.offsetPressure {
                _ = try? await ruuviPool.updateOffsetCorrection(
                    type: .pressure,
                    with: offsetPressure / 100,
                    of: updatedSensor
                )
            }
        }
    }

    private func subscriptionSyncs(
        cloudSensors: [RuuviCloudSensorDense],
        updatedSensors: Set<AnyRuuviTagSensor>
    ) async {
        for cloudSensor in cloudSensors {
            if let updatedSensor = updatedSensors.first(where: { $0.id == cloudSensor.sensor.id }),
               let macId = updatedSensor.macId?.mac,
               let cloudSubscription = cloudSensor.subscription {
                let subscription = cloudSubscription.with(macId: macId)
                _ = try? await ruuviPool.save(subscription: subscription)
            }
        }
    }

    @discardableResult
    public func sync(sensor: RuuviTagSensor) async throws -> [AnyRuuviTagSensorRecord] {
        // Avoid duplicate syncs
        if ongoingHistorySyncs.contains(sensor.any) { return [] }
        guard let maxHistoryDays = sensor.maxHistoryDays, maxHistoryDays > 0 else { return [] }

        let networkPruningOffset = -TimeInterval(ruuviLocalSettings.networkPruningIntervalHours * 60 * 60)
        let networkPuningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let lastSynDate = ruuviLocalSyncState.getSyncDate(for: sensor.macId)
        let syncFullHistory = ruuviLocalSyncState.downloadFullHistory(for: sensor.macId) ?? false
        ruuviLocalSyncState.setSyncStatusHistory(.syncing, for: sensor.macId)
        ongoingHistorySyncs.insert(sensor.any)
        defer {
            ruuviLocalSyncState.setSyncStatusHistory(.none, for: sensor.macId)
            ongoingHistorySyncs.remove(sensor.any)
        }
        let since: Date = syncFullHistory ? networkPuningDate : (lastSynDate ?? networkPuningDate)
        do {
            let result = try await syncRecordsOperation(for: sensor, since: since)
            ruuviLocalSyncState.setSyncStatusHistory(.complete, for: sensor.macId)
            ruuviLocalSyncState.setDownloadFullHistory(for: sensor.macId, downloadFull: false)
            ruuviLocalSyncState.setSyncDate(Date(), for: sensor.macId)
            return result
        } catch let error as RuuviServiceError {
            ruuviLocalSyncState.setSyncStatusHistory(.onError, for: sensor.macId)
            throw error
        }
    }

    @discardableResult
    public func syncAllHistory() async throws -> Bool {
        do {
            let localSensors = try await ruuviStorage.readAll()
            // Build list of sensors that are cloud and need history and have a latest measurement
            var sensorsToSync: [AnyRuuviTagSensor] = []
            for sensor in localSensors where sensor.isCloud {
                if let maxHistoryDays = sensor.maxHistoryDays, maxHistoryDays > 0 {
                    if let _ = try await ruuviStorage.readLatest(sensor) { // ensure at least one record
                        sensorsToSync.append(sensor)
                    }
                }
            }
            for sensor in sensorsToSync {
                _ = try await sync(sensor: sensor)
            }
            return true
        } catch let error as RuuviStorageError {
            throw RuuviServiceError.ruuviStorage(error)
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
        do {
            let localSensors = try await ruuviStorage.readAll()
            for sensor in localSensors {
                if let macId = sensor.macId, sensor.isCloud {
                    ruuviLocalSyncState.setSyncStatusLatestRecord(.syncing, for: macId)
                }
            }
            let denseSensors = try await ruuviCloud.loadSensorsDense(
                for: nil,
                measurements: true,
                sharedToOthers: true,
                sharedToMe: true,
                alerts: true
            )
            guard denseSensors.count > 0 else { return [] }
            let alerts = denseSensors.compactMap { $0.alerts }
            alertService.sync(cloudAlerts: alerts)
            let cloudSensors = denseSensors.map { $0.sensor.any }
            let updatedSensors = try await syncSensors(
                cloudSensors: cloudSensors,
                denseSensor: denseSensors
            )
            let filteredDenseSensorsWithoutHistory = denseSensors.filter { sensor in
                guard let maxHistoryDays = sensor.subscription?.maxHistoryDays else { return false }
                return maxHistoryDays <= 0
            }
            for ruuviTag in filteredDenseSensorsWithoutHistory {
                ruuviLocalSyncState.setSyncDate(
                    ruuviTag.record?.date,
                    for: ruuviTag.sensor.ruuviTagSensor.macId
                )
            }
            // Update latest records and history
            for dense in denseSensors {
                _ = try await updateLatestRecord(
                    ruuviTag: dense.sensor.ruuviTagSensor,
                    cloudRecord: dense.record
                )
            }
            for dense in denseSensors {
                _ = try await addLatestRecordToHistory(
                    ruuviTag: dense.sensor.ruuviTagSensor,
                    cloudRecord: dense.record
                )
            }
            if ruuviLocalSettings.historySyncLegacy || ruuviLocalSettings.historySyncOnDashboard {
                _ = try await syncAllHistory()
            }
            return updatedSensors
        } catch let error as RuuviCloudError {
            switch error {
            case .api(.api(.erUnauthorized)):
                postNotification()
                throw RuuviServiceError.ruuviCloud(error)
            default:
                throw RuuviServiceError.ruuviCloud(error)
            }
        } catch let error as RuuviStorageError {
            throw RuuviServiceError.ruuviStorage(error)
        }
    }

    // swiftlint:disable:next function_body_length
    private func syncSensors(
        cloudSensors: [AnyCloudSensor],
        denseSensor: [RuuviCloudSensorDense]
    ) async throws -> Set<AnyRuuviTagSensor> {
        var updatedSensors = Set<AnyRuuviTagSensor>()
        do {
            let localSensors = try await ruuviStorage.readAll()
            // Update existing local sensors
            for localSensor in localSensors {
                if let cloudSensor = cloudSensors.first(where: { $0.id == localSensor.id }) {
                    updatedSensors.insert(localSensor)
                    if localSensor.ownersPlan?.lowercased() == "free",
                       localSensor.ownersPlan?.lowercased() != cloudSensor.ownersPlan?.lowercased() {
                        ruuviLocalSyncState.setDownloadFullHistory(
                            for: localSensor.macId,
                            downloadFull: true
                        )
                    }
                    do { _ = try await ruuviPool.update(localSensor.with(cloudSensor: cloudSensor)) } catch let e as RuuviPoolError { throw RuuviServiceError.ruuviPool(e) }
                } else {
                    let unclaimed = localSensor.unclaimed()
                    if unclaimed.any != localSensor {
                        updatedSensors.insert(localSensor)
                        do { _ = try await ruuviPool.update(unclaimed) } catch let e as RuuviPoolError { throw RuuviServiceError.ruuviPool(e) }
                    } else if localSensor.isCloud {
                        ruuviLocalSyncState.setDownloadFullHistory(for: localSensor.macId, downloadFull: nil)
                        do { _ = try await ruuviPool.delete(localSensor) } catch let e as RuuviPoolError { throw RuuviServiceError.ruuviPool(e) }
                    }
                }
            }
            // Create new sensors from cloud
            for cloudSensor in cloudSensors where !localSensors.contains(where: { $0.id == cloudSensor.id }) {
                let newLocalSensor = cloudSensor.ruuviTagSensor
                updatedSensors.insert(newLocalSensor.any)
                do { _ = try await ruuviPool.create(newLocalSensor) } catch let e as RuuviPoolError { throw RuuviServiceError.ruuviPool(e) }
            }
            // Sync images concurrently (fire and forget errors)
            let imageSensors = cloudSensors.filter { !ruuviLocalImages.isPictureCached(for: $0) }
            await withTaskGroup(of: Void.self) { group in
                for sensor in imageSensors {
                    group.addTask { [weak self] in
                        guard let self else { return }
                        _ = try? await self.syncImage(sensor: sensor)
                    }
                }
            }
            // Sync subscriptions and offsets
            await subscriptionSyncs(
                cloudSensors: denseSensor,
                updatedSensors: updatedSensors
            )
            await offsetSyncs(
                cloudSensors: cloudSensors,
                updatedSensors: updatedSensors
            )
            return updatedSensors
        } catch let error as RuuviStorageError {
            throw RuuviServiceError.ruuviStorage(error)
        }
    }

    // This method updates the latest data table if a record already exists for the mac address.
    // Otherwise it creates a new record.
    // swiftlint:disable:next function_body_length
    private func updateLatestRecord(
        ruuviTag: RuuviTagSensor,
        cloudRecord: RuuviTagSensorRecord?
    ) async throws -> Bool {
        guard let cloudRecord else {
            ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
            return false
        }
        if cloudRecord.version > 0 && cloudRecord.version != ruuviTag.version {
            try? await ruuviPool.update(ruuviTag.with(version: cloudRecord.version))
        }
        do {
            let record = try await ruuviStorage.readLatest(ruuviTag)
            if let record, record.macId?.value == cloudRecord.macId?.value {
                let isMeasurementNew = cloudRecord.date > record.date
                if ruuviLocalSettings.cloudModeEnabled || isMeasurementNew {
                    do { _ = try await ruuviPool.updateLast(cloudRecord) } catch let e as RuuviPoolError {
                        ruuviLocalSyncState.setSyncStatusLatestRecord(.onError, for: ruuviTag.id.mac)
                        throw RuuviServiceError.ruuviPool(e)
                    }
                    ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
                    return true
                } else {
                    ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
                    return false
                }
            } else {
                do { _ = try await ruuviPool.createLast(cloudRecord) } catch let e as RuuviPoolError {
                    ruuviLocalSyncState.setSyncStatusLatestRecord(.onError, for: ruuviTag.id.mac)
                    throw RuuviServiceError.ruuviPool(e)
                }
                ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
                return true
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
    ) async throws -> Bool {
        guard let cloudRecord else { return false }
        do {
            let record = try await ruuviStorage.readLast(ruuviTag)
            let isMeasurementNew = record.map { cloudRecord.date > $0.date } ?? true
            if ruuviLocalSettings.cloudModeEnabled || isMeasurementNew {
                try await createAndComplete(with: cloudRecord)
                return true
            } else {
                return false
            }
        } catch {
            try await createAndComplete(with: cloudRecord)
            return true
        }
    }

    private func createAndComplete(with cloudRecord: RuuviTagSensorRecord) async throws {
        _ = try? await ruuviPool.create(cloudRecord)
    }

    @discardableResult
    public func syncQueuedRequest(request: RuuviCloudQueuedRequest) async throws -> Bool {
        do {
            let success = try await ruuviCloud.executeQueuedRequest(from: request)
            try? await ruuviPool.deleteQueuedRequest(request)
            return success
        } catch let error as RuuviCloudError {
            switch error {
            case .api(.api(.erConflict)):
                try? await ruuviPool.deleteQueuedRequest(request)
                throw RuuviServiceError.ruuviCloud(error)
            default:
                throw RuuviServiceError.ruuviCloud(error)
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
}
