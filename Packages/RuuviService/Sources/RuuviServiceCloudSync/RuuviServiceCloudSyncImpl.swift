#if SWIFT_PACKAGE
    import RuuviService
#endif
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
    private let cloudSyncedUserSettingsStore: CloudSyncedUserSettingsStore

    // Private property to keep track of ongoing history sync
    private let historyLock = NSLock()
    private let backgroundTasks = RuuviTaskStore()
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
        ruuviAlertService: RuuviServiceAlert
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
        cloudSyncedUserSettingsStore = CloudSyncedUserSettingsStore(
            storage: ruuviStorage,
            localSettings: ruuviLocalSettings
        )
    }

    @discardableResult
    @MainActor
    public func syncSettings() async throws(RuuviServiceError) -> RuuviCloudSettings {
        async let stored = serviceResult { () async throws(RuuviServiceError) in
            try await cloudSyncedUserSettingsStore.readWithFallback()
        }
        let settings: RuuviCloudSettings?
        do { settings = try await ruuviCloud.getCloudSettings() } catch {
            if case .api(.api(.erUnauthorized)) = error { postNotification() }
            throw .ruuviCloud(error)
        }
        guard let settings else { throw .ruuviCloud(.api(.emptyResponse)) }
        let local = try await stored.get()
        await syncUserSettings(localUserSettings: local, cloudSettings: settings)
        backgroundTasks.run { @MainActor [self] in
            if let consent = try? await ruuviCloud.getMarketingConsent() {
                ruuviLocalSettings.marketingPreference = consent.consent
            }
        }
        return settings
    }

    @discardableResult
    @MainActor
    public func syncImage(sensor: CloudSensor) async throws(RuuviServiceError) -> URL {
        guard let picture = sensor.picture else { throw .pictureUrlIsNil }
        let data: Data
        do {
            let response = try await URLSession.shared.data(from: picture)
            if let http = response.1 as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            data = response.0
        } catch { throw .networking(error) }
        guard let image = UIImage(data: data) else { throw .failedToParseNetworkResponse }
        do {
            let url = try await ruuviLocalImages.setCustomBackground(
                image: image, compressionQuality: 1, for: sensor.id.mac)
            ruuviLocalImages.setPictureIsCached(for: sensor)
            return url
        } catch { throw .ruuviLocal(error) }
    }

    @discardableResult
    @MainActor
    public func syncAll() async throws(RuuviServiceError) -> Set<AnyRuuviTagSensor> {
        _ = try await executePendingRequests()
        async let settings = serviceResult { () async throws(RuuviServiceError) in try await syncSettings() }
        let offsets = try await pendingOffsetUpdates()
        let sensors = try await syncSensors(pendingOffsetUpdates: offsets)
        _ = try await settings.get()
        ruuviLocalSyncState.setSyncDate(Date())
        return sensors
    }

    @discardableResult
    @MainActor
    public func refreshLatestRecord() async throws(RuuviServiceError) -> Bool {
        ruuviLocalSyncState.setSyncStatus(.syncing)
        defer { ruuviLocalSyncState.setSyncStatus(.none) }
        do {
            let offsets = try await pendingOffsetUpdates()
            _ = try await syncSensors(pendingOffsetUpdates: offsets)
            ruuviLocalSyncState.setSyncStatus(.complete)
            ruuviLocalSyncState.setSyncDate(Date())
            return true
        } catch {
            ruuviLocalSyncState.setSyncStatus(.onError)
            throw error
        }
    }

    @discardableResult
    @MainActor
    public func syncAllRecords() async throws(RuuviServiceError) -> Bool {
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

    @MainActor
    public func executePendingRequests() async throws(RuuviServiceError) -> Bool {
        guard let requests = try? await ruuviStorage.readQueuedRequests() else { return true }
        // Each queued mutation finishes before a fresh cloud snapshot is fetched.
        for request in requests { _ = try? await syncQueuedRequest(request: request) }
        return true
    }

    @MainActor
    private func pendingOffsetUpdates()
        async throws(RuuviServiceError) -> Set<QueuedOffsetUpdate>?
    {
        var outcome: Result<Set<QueuedOffsetUpdate>?, RuuviServiceError>
        do {
            let requests = try await ruuviStorage.readQueuedRequests(for: .sensor)
            let decoder = JSONDecoder()
            let updates = requests.reduce(into: Set<QueuedOffsetUpdate>()) { result, request in
                guard let data = request.requestBodyData,
                    let update = try? decoder.decode(
                        QueuedSensorUpdateRequest.self,
                        from: data
                    )
                else { return }

                if update.offsetTemperature != nil {
                    result.insert(QueuedOffsetUpdate(sensorID: update.sensor, type: .temperature))
                }
                if update.offsetHumidity != nil {
                    result.insert(QueuedOffsetUpdate(sensorID: update.sensor, type: .humidity))
                }
                if update.offsetPressure != nil {
                    result.insert(QueuedOffsetUpdate(sensorID: update.sensor, type: .pressure))
                }
            }
            outcome = .success(updates)
        } catch let _ {
            // Unknown queue state is not safe for offset reconciliation, but it should not
            // prevent unrelated sensor data from syncing.
            outcome = .success(nil)
        }
        return try outcome.get()
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    private func offsetSyncs(
        cloudSensors: [CloudSensor],
        localSensors: [AnyRuuviTagSensor],
        updatedSensors: Set<AnyRuuviTagSensor>,
        pendingOffsetUpdates: Set<QueuedOffsetUpdate>?
    ) async throws(RuuviPoolError) -> [SensorSettings] {
        guard let pendingOffsetUpdates else { return [] }
        var results = [SensorSettings]()
        for cloudSensor in cloudSensors {
            let matchedSensor =
                updatedSensors.first(where: {
                    cloudSensor.id.isLast3BytesEqual(to: $0.id)
                })
                ?? localSensors.first(where: {
                    cloudSensor.id.isLast3BytesEqual(to: $0.id)
                })

            guard let sensor = matchedSensor else {
                continue
            }

            let localSettings: SensorSettings?
            do { localSettings = try await ruuviStorage.readSensorSettings(sensor) } catch { continue }
            var updates = [SensorSettings]()
            @MainActor
            func reconcile(
                type: OffsetCorrectionType,
                queuedType: QueuedOffsetType,
                localValue: Double?,
                cloudValue: Double?
            ) async throws(RuuviPoolError) {
                let hasPendingUpdate = pendingOffsetUpdates.contains { update in
                    update.type == queuedType
                        && cloudSensor.id.isLast3BytesEqual(to: update.sensorID)
                }
                guard
                    SyncCollisionResolver.resolveOffset(
                        localValue: localValue,
                        cloudValue: cloudValue,
                        hasPendingLocalUpdate: hasPendingUpdate
                    ) == .updateLocal
                else { return }

                updates.append(
                    try await self.ruuviPool.updateOffsetCorrection(
                        type: type,
                        with: cloudValue,
                        of: sensor
                    )
                )
            }

            try await reconcile(
                type: .temperature,
                queuedType: .temperature,
                localValue: localSettings?.temperatureOffset,
                cloudValue: cloudSensor.offsetTemperature
            )
            try await reconcile(
                type: .humidity,
                queuedType: .humidity,
                localValue: localSettings?.humidityOffset,
                cloudValue: cloudSensor.offsetHumidity.map { $0 / 100 }
            )
            try await reconcile(
                type: .pressure,
                queuedType: .pressure,
                localValue: localSettings?.pressureOffset,
                cloudValue: cloudSensor.offsetPressure.map { $0 / 100 }
            )

            if let result = updates.last ?? localSettings { results.append(result) }
        }
        return results
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    private func displaySettingsSyncs(
        denseSensors: [RuuviCloudSensorDense]
    ) async throws(RuuviPoolError) -> [SensorSettings] {
        var results = [SensorSettings]()
        for denseSensor in denseSensors {
            guard let sensorSettings = denseSensor.settings else { continue }
            let sensor = denseSensor.sensor.ruuviTagSensor
            let localSettings = try? await ruuviStorage.readSensorSettings(sensor)
            let displayOrderAction = SyncCollisionResolver.resolve(
                localTimestamp: localSettings?.displayOrderLastUpdated,
                cloudTimestamp: sensorSettings.displayOrderLastUpdated,
                preferCloudWhenBothTimestampsMissing: true
            )

            let defaultOrderAction = SyncCollisionResolver.resolve(
                localTimestamp: localSettings?.defaultDisplayOrderLastUpdated,
                cloudTimestamp: sensorSettings.defaultDisplayOrderLastUpdated,
                preferCloudWhenBothTimestampsMissing: true
            )

            let descriptionAction = SyncCollisionResolver.resolve(
                localTimestamp: localSettings?.descriptionLastUpdated,
                cloudTimestamp: sensorSettings.descriptionLastUpdated,
                preferCloudWhenBothTimestampsMissing: true
            )

            let queueDisplayOrder =
                displayOrderAction == .keepLocalAndQueue
                ? localSettings?.displayOrder
                : nil
            let queueDefaultDisplayOrder =
                defaultOrderAction == .keepLocalAndQueue
                ? localSettings?.defaultDisplayOrder
                : nil
            let shouldQueueDescription = descriptionAction == .keepLocalAndQueue
            let queueDescription =
                shouldQueueDescription
                ? localSettings?.description
                : nil

            if queueDisplayOrder != nil || queueDefaultDisplayOrder != nil || shouldQueueDescription {
                await self.queueDisplaySettingsToCloud(
                    sensor: sensor,
                    displayOrder: queueDisplayOrder,
                    defaultDisplayOrder: queueDefaultDisplayOrder,
                    description: queueDescription,
                    includesDescription: shouldQueueDescription
                )
            }

            guard
                displayOrderAction == .updateLocal
                    || defaultOrderAction == .updateLocal
                    || descriptionAction == .updateLocal
            else {
                continue
            }

            let resolvedDisplayOrder =
                displayOrderAction == .updateLocal
                ? sensorSettings.displayOrderCodes
                : localSettings?.displayOrder
            let resolvedDisplayOrderLastUpdated =
                displayOrderAction == .updateLocal
                ? sensorSettings.displayOrderLastUpdated
                : localSettings?.displayOrderLastUpdated

            let resolvedDefaultDisplayOrder =
                defaultOrderAction == .updateLocal
                ? sensorSettings.defaultDisplayOrder
                : localSettings?.defaultDisplayOrder
            let resolvedDefaultDisplayOrderLastUpdated =
                defaultOrderAction == .updateLocal
                ? sensorSettings.defaultDisplayOrderLastUpdated
                : localSettings?.defaultDisplayOrderLastUpdated
            let resolvedDescription =
                descriptionAction == .updateLocal
                ? sensorSettings.description
                : localSettings?.description
            let resolvedDescriptionLastUpdated =
                descriptionAction == .updateLocal
                ? sensorSettings.descriptionLastUpdated
                : localSettings?.descriptionLastUpdated

            var updates = [SensorSettings]()

            if displayOrderAction == .updateLocal || defaultOrderAction == .updateLocal {
                updates.append(
                    try await self.ruuviPool.updateDisplaySettings(
                        for: sensor,
                        displayOrder: resolvedDisplayOrder,
                        defaultDisplayOrder: resolvedDefaultDisplayOrder,
                        displayOrderLastUpdated: resolvedDisplayOrderLastUpdated,
                        defaultDisplayOrderLastUpdated: resolvedDefaultDisplayOrderLastUpdated
                    )
                )
            }

            if descriptionAction == .updateLocal {
                updates.append(
                    try await self.ruuviPool.updateDescription(
                        for: sensor,
                        description: resolvedDescription,
                        descriptionLastUpdated: resolvedDescriptionLastUpdated
                    )
                )
            }

            if let last = updates.last { results.append(last) }
        }
        return results
    }

    @MainActor
    private func subscriptionSyncs(cloudSensors: [RuuviCloudSensorDense]) async throws(RuuviPoolError)
        -> [CloudSensorSubscription]
    {
        var results = [CloudSensorSubscription]()
        for sensor in cloudSensors {
            if let subscription = sensor.subscription?.with(macId: sensor.sensor.id.mac.mac) {
                results.append(try await ruuviPool.save(subscription: subscription))
            }
        }
        return results
    }

    @discardableResult
    @MainActor
    public func sync(sensor: RuuviTagSensor) async throws(RuuviServiceError) -> [AnyRuuviTagSensorRecord] {
        guard let days = sensor.maxHistoryDays, days > 0 else { return [] }
        let admitted = historyLock.withLock { ongoingHistorySyncs.insert(sensor.any).inserted }
        guard admitted else { return [] }
        defer {
            historyLock.withLock { _ = ongoingHistorySyncs.remove(sensor.any) }
            ruuviLocalSyncState.setSyncStatusHistory(.none, for: sensor.macId)
        }
        let start = Date(timeIntervalSinceNow: -TimeInterval(ruuviLocalSettings.networkPruningIntervalHours * 3600))
        let full = ruuviLocalSyncState.downloadFullHistory(for: sensor.macId) == true
        let since = full ? start : (ruuviLocalSyncState.getSyncDate(for: sensor.macId) ?? start)
        ruuviLocalSyncState.setSyncStatusHistory(.syncing, for: sensor.macId)
        do {
            let records = try await syncRecordsOperation(for: sensor, since: since)
            ruuviLocalSyncState.setSyncStatusHistory(.complete, for: sensor.macId)
            ruuviLocalSyncState.setDownloadFullHistory(for: sensor.macId, downloadFull: false)
            if let date = records.map(\.date).max() { ruuviLocalSyncState.setSyncDate(date, for: sensor.macId) }
            return records
        } catch {
            ruuviLocalSyncState.setSyncStatusHistory(.onError, for: sensor.macId)
            throw error
        }
    }

    @discardableResult
    @MainActor
    public func syncAllHistory() async throws(RuuviServiceError) -> Bool {
        let sensors: [AnyRuuviTagSensor]
        do { sensors = try await ruuviStorage.readAll() } catch { throw .ruuviStorage(error) }
        var eligible = [AnyRuuviTagSensor]()
        for sensor in sensors where sensor.isCloud && (sensor.maxHistoryDays ?? 0) > 0 {
            do {
                if try await ruuviStorage.readLatest(sensor) != nil { eligible.append(sensor) }
            } catch { throw .ruuviStorage(error) }
        }
        _ = try await ruuviConcurrentMap(eligible) { [self] sensor async throws(RuuviServiceError) in
            try await sync(sensor: sensor)
        }
        return true
    }

    @MainActor
    private func syncRecordsOperation(
        for sensor: RuuviTagSensor,
        since: Date
    ) async throws(RuuviServiceError) -> [AnyRuuviTagSensorRecord] {
        guard let mac = sensor.macId else { throw .macIdIsNil }
        let loaded: [AnyRuuviTagSensorRecord]
        do { loaded = try await ruuviCloud.loadRecords(macId: mac, since: since, until: nil) } catch {
            throw .ruuviCloud(error)
        }
        guard !loaded.isEmpty else { return [] }
        let records = loaded.map { record -> AnyRuuviTagSensorRecord in
            if record.luid == nil, let mac = record.macId, let luid = ruuviLocalIDs.luid(for: mac) {
                return record.with(luid: luid).any
            }
            return record
        }
        do { _ = try await ruuviRepository.create(records: records, for: sensor) } catch {
            throw .ruuviRepository(error)
        }
        return records
    }

    // This method syncs the sensors, latest measurements and alerts.
    @MainActor
    // swiftlint:disable:next function_body_length
    private func syncSensors(
        pendingOffsetUpdates: Set<QueuedOffsetUpdate>?
    ) async throws(RuuviServiceError) -> Set<AnyRuuviTagSensor> {
        if let locals = try? await ruuviStorage.readAll() {
            for sensor in locals where sensor.isCloud {
                if let mac = sensor.macId { ruuviLocalSyncState.setSyncStatusLatestRecord(.syncing, for: mac) }
            }
        }
        let dense: [RuuviCloudSensorDense]
        do {
            dense = try await ruuviCloud.loadSensorsDense(
                for: nil, measurements: true, sharedToOthers: true, sharedToMe: true, alerts: true, settings: true
            )
        } catch {
            if case .api(.api(.erUnauthorized)) = error { postNotification() }
            throw .ruuviCloud(error)
        }
        alertService.sync(cloudAlerts: dense.compactMap(\.alerts))
        let updated = try await syncSensors(
            cloudSensors: dense.map { $0.sensor.any }, denseSensor: dense, pendingOffsetUpdates: pendingOffsetUpdates
        )
        for item in dense {
            if let days = item.subscription?.maxHistoryDays, days <= 0 {
                ruuviLocalSyncState.setSyncDate(item.record?.date, for: item.sensor.ruuviTagSensor.macId)
            }
            _ = try await updateLatestRecord(ruuviTag: item.sensor.ruuviTagSensor, cloudRecord: item.record)
            _ = try await addLatestRecordToHistory(ruuviTag: item.sensor.ruuviTagSensor, cloudRecord: item.record)
        }
        return updated
    }

    @MainActor
    private func syncUserSettings(
        localUserSettings: [RuuviUserSetting],
        cloudSettings: RuuviCloudSettings
    ) async {
        let localSettingsByKey = userSettingsByKey(localUserSettings)
        let cloudSettingsByKey = userSettingsByKey(cloudSettings.userSettings)
        var cloudSettingsToSave = [RuuviUserSetting]()

        for setting in RuuviCloudApiSetting.cloudSyncedUserSettings {
            let localSetting = localSettingsByKey[setting.key]
            let cloudSetting = cloudSettingsByKey[setting.key]
            let syncAction = syncAction(
                localSetting: localSetting,
                cloudSetting: cloudSetting
            )

            switch syncAction {
            case .keepLocalAndQueue:
                guard let localSetting else {
                    continue
                }
                // Earlier keys in this sync pass can mutate shared UserDefaults.
                // Re-apply the local winner so timestamp conflict resolution is
                // reflected in the active settings, not only in SQL.
                if setting.isAppliedFromCloud {
                    setting.apply(
                        userSetting: localSetting,
                        to: ruuviLocalSettings
                    )
                }
                if shouldUploadLocalSetting(localSetting, over: cloudSetting) {
                    await setting.upload(
                        userSetting: localSetting,
                        using: ruuviCloud
                    )
                }
            case .updateLocal:
                if let cloudSetting {
                    setting.apply(
                        userSetting: cloudSetting,
                        to: ruuviLocalSettings
                    )
                    cloudSettingsToSave.append(cloudSetting)
                }
            case .noAction:
                if cloudSetting == nil {
                    await uploadMissingCloudUserSetting(setting)
                }
            }
        }

        guard !cloudSettingsToSave.isEmpty else {
            return
        }
        _ = try? await cloudSyncedUserSettingsStore.saveSyncedSettings(cloudSettingsToSave)
    }

    private func syncAction(
        localSetting: RuuviUserSetting?,
        cloudSetting: RuuviUserSetting?
    ) -> SyncAction {
        SyncCollisionResolver.resolve(
            localTimestamp: localSetting?.lastUpdated,
            cloudTimestamp: cloudSetting?.lastUpdated,
            preferCloudWhenBothTimestampsMissing: cloudSetting != nil
        )
    }

    private func userSettingsByKey(
        _ userSettings: [RuuviUserSetting]
    ) -> [String: RuuviUserSetting] {
        userSettings.reduce(into: [:]) { result, userSetting in
            result[userSetting.key] = userSetting
        }
    }

    private func shouldUploadLocalSetting(
        _ localSetting: RuuviUserSetting,
        over cloudSetting: RuuviUserSetting?
    ) -> Bool {
        guard let cloudSetting else {
            return true
        }
        return localSetting.value != cloudSetting.value
    }

    @MainActor
    private func uploadMissingCloudUserSetting(
        _ setting: RuuviCloudApiSetting
    ) async {
        guard
            let fallbackSetting = setting.missingCloudUserSetting(
                from: ruuviLocalSettings,
                lastUpdated: UserSettingTimestamp.current()
            )
        else {
            return
        }
        setting.apply(
            userSetting: fallbackSetting,
            to: ruuviLocalSettings
        )
        await setting.upload(
            userSetting: fallbackSetting,
            using: ruuviCloud
        )
    }

    @MainActor
    // swiftlint:disable:next function_body_length
    private func syncSensors(
        cloudSensors: [AnyCloudSensor],
        denseSensor: [RuuviCloudSensorDense],
        pendingOffsetUpdates: Set<QueuedOffsetUpdate>?
    ) async throws(RuuviServiceError) -> Set<AnyRuuviTagSensor> {
        let localSensors: [AnyRuuviTagSensor]
        do { localSensors = try await ruuviStorage.readAll() } catch { throw .ruuviStorage(error) }
        var updatedSensors = Set<AnyRuuviTagSensor>()
        var skipCloudImageDownloadForSensorIDs = Set<String>()
        do {
            for localSensor in localSensors {
                if let cloudSensor = cloudSensors.first(where: {
                    $0.id.isLast3BytesEqual(to: localSensor.id)
                }) {
                    // Resolve sync collision based on timestamps
                    let resolvedAction = SyncCollisionResolver.resolve(
                        localTimestamp: localSensor.lastUpdated,
                        cloudTimestamp: cloudSensor.lastUpdated,
                        preferCloudWhenBothTimestampsMissing: true
                    )
                    let syncAction: SyncAction = {
                        if resolvedAction == .noAction,
                            SyncCollisionResolver.shouldRefreshCloudAuthoritativeFields(
                                localSensor: localSensor,
                                cloudSensor: cloudSensor
                            )
                        {
                            return .updateLocal
                        }
                        return resolvedAction
                    }()
                    switch syncAction {
                    case .updateLocal:
                        updatedSensors.insert(localSensor)
                        // Update the local sensor data with cloud data
                        // if there's a match of sensor in local storage and cloud
                        // TODO: @priyonto - Need to improve this once backend flattens and improves the plans
                        self.handleDownloadFullHistoryAfterSubscriptionChange(
                            localSensor: localSensor,
                            cloudSensor: cloudSensor
                        )
                        _ = try await self.ruuviPool.update(localSensor.with(cloudSensor: cloudSensor))

                    case .keepLocalAndQueue:
                        // Local is newer - push local editable fields to cloud, but keep
                        // cloud-authoritative entitlement fields fresh locally.
                        skipCloudImageDownloadForSensorIDs.insert(cloudSensor.id)
                        if localSensor.macId != nil {
                            _ = await self.queueSensorUpdateToCloud(localSensor)
                        }
                        await self.queueSensorImageUpdateToCloud(
                            localSensor: localSensor,
                            cloudSensor: cloudSensor
                        )

                        self.handleDownloadFullHistoryAfterSubscriptionChange(
                            localSensor: localSensor,
                            cloudSensor: cloudSensor
                        )

                        guard
                            self.shouldRefreshCloudSubscriptionFieldsForLocalNewerSensor(
                                localSensor: localSensor,
                                cloudSensor: cloudSensor
                            )
                        else {
                            continue
                        }

                        let refreshedSensor = self.subscriptionRefreshedSensor(
                            localSensor: localSensor,
                            cloudSensor: cloudSensor
                        )
                        updatedSensors.insert(refreshedSensor.any)
                        _ = try await self.ruuviPool.update(refreshedSensor)

                    case .noAction:
                        // Timestamps are equal or within tolerance - no update needed
                        continue
                    }
                } else {
                    // If there is a local sensor which is claimed and deleted from the cloud,
                    // delete it from local storage
                    // Otherwise keep it stored
                    if localSensor.isCloud {
                        self.ruuviLocalSyncState.setDownloadFullHistory(
                            for: localSensor.macId,
                            downloadFull: nil
                        )
                        _ = try await self.ruuviPool.delete(localSensor)
                    }

                    // The cloud sensor list only contains sensors accessible to the
                    // signed-in user. A locally discovered sensor owned by somebody else
                    // is therefore expected to be absent and must retain its owner.
                    guard localSensor.isOwner else {
                        continue
                    }

                    guard localSensor.isClaimed || localSensor.owner != nil || localSensor.ownersPlan != nil else {
                        continue
                    }

                    let unclaimed = localSensor.unclaimed()
                    updatedSensors.insert(unclaimed.any)
                    _ = try await self.ruuviPool.update(unclaimed)
                }
            }
            for cloud in cloudSensors where !localSensors.contains(where: { $0.id.isLast3BytesEqual(to: cloud.id) }) {
                let sensor = cloud.ruuviTagSensor
                _ = try await ruuviPool.create(sensor)
                updatedSensors.insert(sensor.any)
            }
            _ = try await subscriptionSyncs(cloudSensors: denseSensor)
            _ = try await offsetSyncs(
                cloudSensors: cloudSensors, localSensors: localSensors,
                updatedSensors: updatedSensors, pendingOffsetUpdates: pendingOffsetUpdates)
            _ = try await displaySettingsSyncs(denseSensors: denseSensor)
        } catch { throw .ruuviPool(error) }
        for sensor in cloudSensors
        where !skipCloudImageDownloadForSensorIDs.contains(sensor.id) && !ruuviLocalImages.isPictureCached(for: sensor)
        {
            backgroundTasks.run { @MainActor [self] in _ = try? await syncImage(sensor: sensor) }
        }
        return updatedSensors
    }

    private func handleDownloadFullHistoryAfterSubscriptionChange(
        localSensor: RuuviTagSensor,
        cloudSensor: CloudSensor
    ) {
        guard
            hasSubscriptionChanged(
                localSensor: localSensor,
                cloudSensor: cloudSensor
            )
        else { return }

        if shouldDownloadFullHistoryAfterSubscriptionChange(
            localSensor: localSensor,
            cloudSensor: cloudSensor
        ) {
            ruuviLocalSyncState.setDownloadFullHistory(
                for: localSensor.macId,
                downloadFull: true
            )
        } else if shouldClearDownloadFullHistoryAfterSubscriptionChange(
            cloudSensor: cloudSensor
        ) {
            ruuviLocalSyncState.setDownloadFullHistory(
                for: localSensor.macId,
                downloadFull: nil
            )
        }
    }

    private func hasSubscriptionChanged(
        localSensor: RuuviTagSensor,
        cloudSensor: CloudSensor
    ) -> Bool {
        localSensor.ownersPlan?.lowercased() != cloudSensor.ownersPlan?.lowercased()
            || localSensor.maxHistoryDays != cloudSensor.maxHistoryDays
    }

    private func shouldDownloadFullHistoryAfterSubscriptionChange(
        localSensor: RuuviTagSensor,
        cloudSensor: CloudSensor
    ) -> Bool {
        let localPlan = localSensor.ownersPlan?.lowercased()
        let cloudPlan = cloudSensor.ownersPlan?.lowercased()
        let localHistoryDays = localSensor.maxHistoryDays ?? 0
        let cloudHistoryDays = cloudSensor.maxHistoryDays ?? 0
        let planChangedFromFreeWithHistory =
            localPlan == "free"
            && cloudPlan != nil
            && cloudPlan != "free"
            && cloudHistoryDays > 0
        let historyExpanded = cloudHistoryDays > localHistoryDays

        return planChangedFromFreeWithHistory || historyExpanded
    }

    private func shouldClearDownloadFullHistoryAfterSubscriptionChange(
        cloudSensor: CloudSensor
    ) -> Bool {
        let cloudHistoryDays = cloudSensor.maxHistoryDays ?? 0

        return cloudHistoryDays <= 0
    }

    private func shouldRefreshCloudSubscriptionFieldsForLocalNewerSensor(
        localSensor: RuuviTagSensor,
        cloudSensor: CloudSensor
    ) -> Bool {
        localSensor.ownersPlan != cloudSensor.ownersPlan
            || localSensor.maxHistoryDays != cloudSensor.maxHistoryDays
    }

    private func subscriptionRefreshedSensor(
        localSensor: RuuviTagSensor,
        cloudSensor: CloudSensor
    ) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            version: localSensor.version,
            firmwareVersion: localSensor.firmwareVersion,
            luid: localSensor.luid,
            macId: localSensor.macId,
            serviceUUID: localSensor.serviceUUID,
            isConnectable: localSensor.isConnectable,
            name: localSensor.name,
            isClaimed: localSensor.isClaimed,
            isOwner: localSensor.isOwner,
            owner: localSensor.owner,
            ownersPlan: cloudSensor.ownersPlan,
            isCloudSensor: localSensor.isCloudSensor,
            canShare: localSensor.canShare,
            sharedTo: localSensor.sharedTo,
            sharedToPending: localSensor.sharedToPending,
            maxHistoryDays: cloudSensor.maxHistoryDays,
            lastUpdated: localSensor.lastUpdated
        )
    }

    // This method updates the latest data table if a record already exists for the mac address.
    // Otherwise it creates a new record.
    @MainActor
    // swiftlint:disable:next function_body_length
    private func updateLatestRecord(
        ruuviTag: RuuviTagSensor,
        cloudRecord: RuuviTagSensorRecord?
    )
        async throws(RuuviServiceError) -> Bool
    {
        guard let cloudRecord else {
            ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
            return false
        }
        if cloudRecord.version > 0, let local = try? await ruuviStorage.readOne(ruuviTag.id),
            local.version != cloudRecord.version
        {
            _ = try? await ruuviPool.update(local.with(version: cloudRecord.version))
        }
        let record: RuuviTagSensorRecord?
        do { record = try await ruuviStorage.readLatest(ruuviTag) } catch {
            ruuviLocalSyncState.setSyncStatusLatestRecord(.onError, for: ruuviTag.id.mac)
            throw .ruuviStorage(error)
        }
        do {
            if let record, let mac = record.macId, mac.any == cloudRecord.macId?.any {
                guard ruuviLocalSettings.cloudModeEnabled || cloudRecord.date > record.date else {
                    ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
                    return false
                }
                _ = try await ruuviPool.updateLast(cloudRecord.with(macId: mac.any))
            } else {
                _ = try await ruuviPool.createLast(cloudRecord)
            }
        } catch {
            ruuviLocalSyncState.setSyncStatusLatestRecord(.onError, for: ruuviTag.id.mac)
            throw .ruuviPool(error)
        }
        ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
        return true
    }

    /// This method writes the latest data point to the history/records table
    @MainActor
    private func addLatestRecordToHistory(
        ruuviTag: RuuviTagSensor,
        cloudRecord: RuuviTagSensorRecord?
    )
        async throws(RuuviServiceError) -> Bool
    {
        guard let cloudRecord else { return false }
        let record: RuuviTagSensorRecord?
        do { record = try await ruuviStorage.readLast(ruuviTag) } catch { throw .ruuviStorage(error) }
        if let record {
            guard ruuviLocalSettings.cloudModeEnabled || cloudRecord.date > record.date else { return false }
        }
        let macId = record?.macId?.any ?? ruuviTag.macId?.any ?? cloudRecord.macId?.any
        let normalized = macId.map { cloudRecord.with(macId: $0) } ?? cloudRecord
        do { _ = try await ruuviPool.create(normalized); return true } catch { throw .ruuviPool(error) }
    }

    @discardableResult
    @MainActor
    public func syncQueuedRequest(request: RuuviCloudQueuedRequest) async throws(RuuviServiceError) -> Bool {
        let success: Bool
        do { success = try await ruuviCloud.executeQueuedRequest(from: request) } catch {
            if case .api(.api(.erConflict)) = error {
                do { _ = try await ruuviPool.deleteQueuedRequest(request) } catch { throw .ruuviPool(error) }
            }
            throw .ruuviCloud(error)
        }
        do { _ = try await ruuviPool.deleteQueuedRequest(request) } catch { throw .ruuviPool(error) }
        return success
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
    @MainActor
    private func queueSensorUpdateToCloud(_ sensor: RuuviTagSensor) async -> Bool {
        _ = try? await ruuviCloud.update(name: sensor.name, for: sensor)
        return true
    }

    /// Queue local sensor background image update to cloud when local data is newer.
    /// If local has a custom image it is uploaded, otherwise cloud image is reset.
    @MainActor
    private func queueSensorImageUpdateToCloud(localSensor: RuuviTagSensor, cloudSensor: CloudSensor) async {
        guard let mac = localSensor.macId else { return }
        if let image = localCustomBackground(for: localSensor) {
            guard !ruuviLocalImages.isPictureCached(for: cloudSensor),
                let data = image.jpegData(compressionQuality: 1)
            else { return }
            _ = try? await ruuviCloud.upload(imageData: data, mimeType: .jpg, progress: nil, for: mac)
        } else if cloudSensor.picture != nil {
            _ = try? await ruuviCloud.resetImage(for: mac)
        }
    }

    private func localCustomBackground(for sensor: RuuviTagSensor) -> UIImage? {
        if let macId = sensor.macId,
            let image = ruuviLocalImages.getCustomBackground(for: macId)
        {
            return image
        }

        if let luid = sensor.luid,
            let image = ruuviLocalImages.getCustomBackground(for: luid)
        {
            return image
        }

        return nil
    }

    /// Queue local display settings update to cloud when local data is newer.
    @MainActor
    private func queueDisplaySettingsToCloud(
        sensor: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        description: String?,
        includesDescription: Bool
    ) async {
        guard sensor.isCloud else { return }

        var types: [String] = []
        var values: [String] = []

        if let defaultOrder = defaultDisplayOrder {
            types.append(RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue)
            values.append(defaultOrder ? "true" : "false")
        }

        if let displayOrder, !displayOrder.isEmpty,
            let data = try? JSONEncoder().encode(displayOrder),
            let encoded = String(data: data, encoding: .utf8)
        {
            types.append(RuuviCloudApiSetting.sensorDisplayOrder.rawValue)
            values.append(encoded)
        }

        if includesDescription {
            types.append(RuuviCloudApiSetting.sensorDescription.rawValue)
            values.append(description ?? "")
        }

        guard !types.isEmpty else { return }

        _ = try? await ruuviCloud.updateSensorSettings(
            for: sensor,
            types: types,
            values: values,
            timestamp: Int(Date().timeIntervalSince1970)
        )
    }

}

private func serviceResult<Value>(
    _ operation: () async throws(RuuviServiceError) -> Value
) async -> Result<Value, RuuviServiceError> {
    do throws(RuuviServiceError) { return .success(try await operation()) } catch { return .failure(error) }
}
