import Foundation
import Future
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
    public func syncSettings() -> Future<RuuviCloudSettings, RuuviServiceError> {
        let promise = Promise<RuuviCloudSettings, RuuviServiceError>()
        ruuviCloud.getCloudSettings()
            .observe(on: .global(qos: .utility))
            .on(success: { [weak self] cloudSettings in
                guard let cloudSettings, let sSelf = self else { return }
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
                    // Draw dots feature is disabled from v1.3.0 onwards to
                    // maintain better performance until we find a better approach to do it.
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
                    if cloudProfileLanguageCode !=
                        sSelf.ruuviLocalSettings.cloudProfileLanguageCode {
                        sSelf.ruuviLocalSettings.cloudProfileLanguageCode = cloudProfileLanguageCode
                    }
                } else {
                    let languageCode = sSelf.ruuviLocalSettings.language.rawValue
                    sSelf.ruuviAppSettingsService.set(
                        profileLanguageCode: languageCode
                    )
                    sSelf.ruuviLocalSettings.cloudProfileLanguageCode = languageCode
                }

                if let dashboardSensorOrderString = cloudSettings.dashboardSensorOrder,
                   let dashboardSensorOrder = RuuviCloudApiHelper.jsonArrayFromString(dashboardSensorOrderString),
                   dashboardSensorOrder != sSelf.ruuviLocalSettings.dashboardSensorOrder {
                    sSelf.ruuviLocalSettings.dashboardSensorOrder = dashboardSensorOrder
                }

                promise.succeed(value: cloudSettings)
            }, failure: { [weak self] error in
                switch error {
                case .api(.api(.erUnauthorized)):
                    self?.postNotification()
                default:
                    promise.fail(error: .ruuviCloud(error))
                }
            })
        return promise.future
    }

    @discardableResult
    public func syncImage(sensor: CloudSensor) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        guard let pictureUrl = sensor.picture
        else {
            promise.fail(error: .pictureUrlIsNil)
            return promise.future
        }
        URLSession
            .shared
            .dataTask(with: pictureUrl,
                      completionHandler: {
                data,
                _,
                error in
                if let error {
                    promise.fail(error: .networking(error))
                } else if let data {
                    if let image = UIImage(data: data) {
                        // Sync the image with original quality from cloud
                        DispatchQueue.main.async {
                            self.ruuviLocalImages
                                .setCustomBackground(
                                    image: image,
                                    compressionQuality: 1.0,
                                    for: sensor.id.mac
                                )
                                .observe(on: .global(qos: .utility))
                                .on(success: { fileUrl in
                                    self.ruuviLocalImages.setPictureIsCached(for: sensor)
                                    promise.succeed(value: fileUrl)
                                }, failure: { error in
                                    promise.fail(error: .ruuviLocal(error))
                                })
                        }
                    } else {
                        promise.fail(error: .failedToParseNetworkResponse)
                    }
                } else {
                    promise.fail(error: .failedToParseNetworkResponse)
                }
            }).resume()
        return promise.future
    }

    @discardableResult
    public func syncAll() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError> {
        let promise = Promise<Set<AnyRuuviTagSensor>, RuuviServiceError>()

        let queuedRequests = executePendingRequests()
        let settings = syncSettings()
        let sensors = syncSensors()

        queuedRequests
            .observe(on: .global(qos: .utility))
            .on(success: { _ in
                settings
                    .observe(on: .global(qos: .utility))
                    .on(success: { _ in
                        sensors
                            .observe(on: .global(qos: .utility))
                            .on(success: { [weak self] updatedSensors in
                                self?.ruuviLocalSyncState.setSyncDate(Date())
                                promise.succeed(value: updatedSensors)
                            }, failure: { error in
                                promise.fail(error: error)
                            })
                    }, failure: { error in
                        promise.fail(error: error)
                    })
            }, failure: { error in
                promise.fail(error: error)
            })
        return promise.future
    }

    @discardableResult
    public func refreshLatestRecord() -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        ruuviLocalSyncState.setSyncStatus(.syncing)
        syncSensors()
            .observe(on: .global(qos: .utility))
            .on(success: { [weak self] _ in
                self?.ruuviLocalSyncState.setSyncStatus(.complete)
                self?.ruuviLocalSyncState.setSyncDate(Date())
                promise.succeed(value: true)
            }, failure: { [weak self] error in
                self?.ruuviLocalSyncState.setSyncStatus(.onError)
                promise.fail(error: error)
            }, completion: { [weak self] in
                self?.ruuviLocalSyncState.setSyncStatus(.none)
            })
        return promise.future
    }

    @discardableResult
    public func syncAllRecords() -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        ruuviLocalSettings.isSyncing = true
        ruuviLocalSyncState.setSyncStatus(.syncing)
        let syncAll = syncAll()
        syncAll
            .observe(on: .global(qos: .utility))
            .on(success: { [weak self] _ in
                self?.ruuviLocalSyncState.setSyncStatus(.complete)
                promise.succeed(value: true)
            }, failure: { [weak self] error in
                self?.ruuviLocalSyncState.setSyncStatus(.onError)
                promise.fail(error: error)
            }, completion: { [weak self] in
                self?.ruuviLocalSyncState.setSyncStatus(.none)
                self?.ruuviLocalSettings.isSyncing = false
            })
        return promise.future
    }

    public func executePendingRequests() -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        ruuviStorage.readQueuedRequests()
            .observe(on: .global(qos: .utility))
            .on(success: { [weak self] requests in
                guard requests.count > 0
                else {
                    return promise.succeed(value: true)
                }

                let queuedRequests = requests.compactMap { request in
                    self?.syncQueuedRequest(request: request)
                }

                Future.zip(queuedRequests).on(completion: {
                    promise.succeed(value: true)
                })
            })
        return promise.future
    }

    // swiftlint:disable:next function_body_length
    private func offsetSyncs(
        cloudSensors: [CloudSensor],
        updatedSensors: Set<AnyRuuviTagSensor>
    ) -> [Future<SensorSettings, RuuviPoolError>] {
        var allSyncs: [Future<SensorSettings, RuuviPoolError>] = []

        for cloudSensor in cloudSensors {
            guard let updatedSensor = updatedSensors.first(where: { $0.id == cloudSensor.id }) else {
                continue
            }

            let cloudTimestamp = cloudSensor.lastUpdated ?? 0
            let localTimestamp = updatedSensor.lastUpdated ?? 0

            // If local is newer, queue offset update to cloud
            if localTimestamp > cloudTimestamp && updatedSensor.isOwner {
                // Read local settings and push to cloud
                ruuviStorage.readSensorSettings(updatedSensor)
                    .observe(on: .global(qos: .utility))
                    .on(success: { [weak self] localSettings in
                        guard let localSettings else { return }
                        self?.queueOffsetUpdateToCloud(
                            localSensor: updatedSensor,
                            localSettings: localSettings
                        )
                    })
                // Don't update local with cloud offsets - local is newer
                continue
            }

            // Cloud is newer or equal - update local with cloud offsets
            let tempSync = self.ruuviPool.updateOffsetCorrection(
                type: .temperature,
                with: cloudSensor.offsetTemperature,
                of: updatedSensor,
                lastOriginalRecord: nil,
                lastUpdatedTimestamp: cloudSensor.lastUpdated
            )
            allSyncs.append(tempSync)

            if let offsetHumidity = cloudSensor.offsetHumidity {
                let humiditySync = self.ruuviPool.updateOffsetCorrection(
                    type: .humidity,
                    with: offsetHumidity / 100,
                    of: updatedSensor,
                    lastOriginalRecord: nil,
                    lastUpdatedTimestamp: cloudSensor.lastUpdated
                )
                allSyncs.append(humiditySync)
            }

            if let offsetPressure = cloudSensor.offsetPressure {
                let pressureSync = self.ruuviPool.updateOffsetCorrection(
                    type: .pressure,
                    with: offsetPressure / 100,
                    of: updatedSensor,
                    lastOriginalRecord: nil,
                    lastUpdatedTimestamp: cloudSensor.lastUpdated
                )
                allSyncs.append(pressureSync)
            }
        }

        return allSyncs
    }

    // swiftlint:disable:next function_body_length
    private func displaySettingsSyncs(
        denseSensors: [RuuviCloudSensorDense]
    ) -> [Future<SensorSettings, RuuviPoolError>] {
        var allSyncs: [Future<SensorSettings, RuuviPoolError>] = []

        for denseSensor in denseSensors {
            guard let cloudSettings = denseSensor.settings else {
                continue
            }

            let localSensor = denseSensor.sensor.ruuviTagSensor
            let promise = Promise<SensorSettings, RuuviPoolError>()
            allSyncs.append(promise.future)

            // Read local settings to compare timestamps
            ruuviStorage.readSensorSettings(localSensor)
                .observe(on: .global(qos: .utility))
                .on(success: { [weak self] localSettings in
                    guard let self else {
                        let fallback = localSettings ?? SensorSettingsStruct(
                            luid: localSensor.luid,
                            macId: localSensor.macId,
                            temperatureOffset: nil,
                            humidityOffset: nil,
                            pressureOffset: nil,
                            displayOrder: cloudSettings.displayOrderCodes,
                            defaultDisplayOrder: cloudSettings.defaultDisplayOrder,
                            displayOrderLastUpdated: cloudSettings.displayOrderLastUpdated,
                            defaultDisplayOrderLastUpdated: cloudSettings.defaultDisplayOrderLastUpdated
                        )
                        promise.succeed(value: fallback)
                        return
                    }

                    let cloudDisplayOrderTs = cloudSettings.displayOrderLastUpdated ?? 0
                    let localDisplayOrderTs = localSettings?.displayOrderLastUpdated ?? 0

                    let cloudDefaultDisplayOrderTs = cloudSettings.defaultDisplayOrderLastUpdated ?? 0
                    let localDefaultDisplayOrderTs = localSettings?.defaultDisplayOrderLastUpdated ?? 0

                    // If local display order is newer, push to cloud
                    if localDisplayOrderTs > cloudDisplayOrderTs,
                       let localDisplayOrder = localSettings?.displayOrder,
                       localSensor.isOwner {
                        self.queueDisplaySettingsToCloud(
                            localSensor: localSensor,
                            displayOrder: localDisplayOrder
                        )
                    }

                    // If local default display order is newer, push to cloud
                    if localDefaultDisplayOrderTs > cloudDefaultDisplayOrderTs,
                       let localDefaultDisplayOrder = localSettings?.defaultDisplayOrder,
                       localSensor.isOwner {
                        self.queueDefaultDisplayOrderToCloud(
                            localSensor: localSensor,
                            defaultDisplayOrder: localDefaultDisplayOrder
                        )
                    }

                    // Only update local with cloud data if cloud is newer
                    let shouldUpdateDisplayOrder = cloudDisplayOrderTs > localDisplayOrderTs
                    let shouldUpdateDefaultDisplayOrder = cloudDefaultDisplayOrderTs > localDefaultDisplayOrderTs

                    if shouldUpdateDisplayOrder || shouldUpdateDefaultDisplayOrder {
                        self.ruuviPool.updateDisplaySettings(
                            for: localSensor,
                            displayOrder: shouldUpdateDisplayOrder ? cloudSettings.displayOrderCodes : nil,
                            defaultDisplayOrder: shouldUpdateDefaultDisplayOrder ? cloudSettings.defaultDisplayOrder : nil,
                            displayOrderTimestamp: shouldUpdateDisplayOrder ? cloudSettings.displayOrderLastUpdated : nil,
                            defaultDisplayOrderTimestamp: shouldUpdateDefaultDisplayOrder ? cloudSettings.defaultDisplayOrderLastUpdated : nil
                        )
                        .on(success: { settings in
                            promise.succeed(value: settings)
                        }, failure: { error in
                            promise.fail(error: error)
                        })
                    } else if let localSettings {
                        promise.succeed(value: localSettings)
                    } else {
                        let fallback = SensorSettingsStruct(
                            luid: localSensor.luid,
                            macId: localSensor.macId,
                            temperatureOffset: nil,
                            humidityOffset: nil,
                            pressureOffset: nil,
                            displayOrder: cloudSettings.displayOrderCodes,
                            defaultDisplayOrder: cloudSettings.defaultDisplayOrder,
                            displayOrderLastUpdated: max(localDisplayOrderTs, cloudDisplayOrderTs),
                            defaultDisplayOrderLastUpdated: max(localDefaultDisplayOrderTs, cloudDefaultDisplayOrderTs)
                        )
                        promise.succeed(value: fallback)
                    }
                }, failure: { error in
                    switch error {
                    case let .ruuviPersistence(persistenceError):
                        promise.fail(error: .ruuviPersistence(persistenceError))
                    }
                })
        }

        return allSyncs
    }

    private func subscriptionSyncs(
        cloudSensors: [RuuviCloudSensorDense],
        updatedSensors: Set<AnyRuuviTagSensor>
    ) -> [Future<CloudSensorSubscription, RuuviPoolError>] {
        let syncs: [Future<CloudSensorSubscription, RuuviPoolError>]
        = cloudSensors.compactMap { [weak self] cloudSensor in
            if let updatedSensor = updatedSensors
                .first(where: { $0.id == cloudSensor.sensor.id }),
               let macId = updatedSensor.macId?.mac,
               let cloudSubscription = cloudSensor.subscription {
                let subscription = cloudSubscription.with(macId: macId)
                return self?.ruuviPool.save(subscription: subscription)
            } else {
                return nil
            }
        }

        return syncs
    }

    @discardableResult
    public func sync(sensor: RuuviTagSensor) -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviServiceError>()

        // Check if a history sync is already in progress for this sensor
        // and return early if so.
        if ongoingHistorySyncs.contains(sensor.any) {
            return promise.future
        }

        guard let maxHistoryDays = sensor.maxHistoryDays, maxHistoryDays > 0 else {
            return promise.future
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
        let since: Date = syncFullHistory ? networkPuningDate : (lastSynDate ?? networkPuningDate)
        syncRecordsOperation(for: sensor, since: since)
            .observe(on: .global(qos: .utility))
            .on(success: { [weak self] result in
                self?.ruuviLocalSyncState.setSyncStatusHistory(.complete, for: sensor.macId)
                self?.ruuviLocalSyncState.setDownloadFullHistory(for: sensor.macId, downloadFull: false)
                self?.ruuviLocalSyncState.setSyncDate(
                    Date(),
                    for: sensor.macId
                )
                promise.succeed(value: result)
            }, failure: { [weak self] error in
                self?.ruuviLocalSyncState
                    .setSyncStatusHistory(.onError, for: sensor.macId)
                promise.fail(error: error)
            }, completion: { [weak self] in
                self?.ruuviLocalSyncState
                    .setSyncStatusHistory(.none, for: sensor.macId)
                self?.ongoingHistorySyncs.remove(sensor.any)
            })
        return promise.future
    }

    @discardableResult
    public func syncAllHistory() -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()

        ruuviStorage.readAll()
            .observe(on: .global(qos: .utility))
            .on(success: { [weak self] localSensors in
                guard let sSelf = self else { return }

                // Read the latest record for each sensor asynchronously, filter sensors with history.
                let sensorHistoryFutures = localSensors.compactMap {
                    sensor -> Future<(AnyRuuviTagSensor, RuuviTagSensorRecord?), RuuviServiceError>? in

                    // Sensor should be a cloud sensor with allow max history days greater than 0.
                    // Also, the sensor should already have a measurement on the latest measurement
                    // table from database.
                    guard sensor.isCloud,
                          let maxHistoryDays = sensor.maxHistoryDays,
                          maxHistoryDays > 0 else {
                        return nil
                    }

                    // Read the latest record for the sensor
                    return sSelf.ruuviStorage.readLatest(sensor).map { record in
                        (sensor, record)
                    }.mapError({ error in
                        return .ruuviStorage(error)
                    })
                }

                Future.zip(sensorHistoryFutures)
                    .observe(on: .global(qos: .utility))
                    .on(success: { sensorRecords in
                        // Filter sensors that have no records, then sync
                        let sensorsToSync = sensorRecords
                            .filter { $0.1 != nil } // Only include sensors that have a valid record
                            .map { $0.0 } // Extract the sensors

                        let syncHistoryFutures = sensorsToSync.map { sSelf.sync(sensor: $0) }

                        // Zip all sync operations together and handle the final result
                        Future.zip(syncHistoryFutures)
                            .observe(on: .global(qos: .utility))
                            .on(success: { _ in
                                promise.succeed(value: true)
                            }, failure: { error in
                                promise.fail(error: error)
                            })
                    }, failure: { error in
                        promise.fail(error: error)
                    })
            })

        return promise.future
    }

    private lazy var syncRecordsQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    private func syncRecordsOperation(
        for sensor: RuuviTagSensor,
        since: Date
    ) -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviServiceError>()
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
                promise.fail(error: error)
            } else {
                promise.succeed(value: operation.records)
            }
        }
        syncRecordsQueue.addOperation(operation)
        return promise.future
    }

    // This method syncs the sensors, latest measurements and alerts.
    // swiftlint:disable:next function_body_length
    private func syncSensors() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError> {
        let promise = Promise<Set<AnyRuuviTagSensor>, RuuviServiceError>()

        // Set cloud sensors in syncing state
        // Skip the sensors if not claimed or cloud sensors
        ruuviStorage.readAll()
            .observe(on: .global(qos: .utility))
            .on(success: { [weak self] localSensors in
                guard let sSelf = self else { return }
                for sensor in localSensors {
                    if let macId = sensor.macId, sensor.isCloud {
                        sSelf.ruuviLocalSyncState.setSyncStatusLatestRecord(.syncing, for: macId)
                    }
                }
            })

        // Fetch data from the dense endpoint
        ruuviCloud.loadSensorsDense(
            for: nil,
            measurements: true,
            sharedToOthers: true,
            sharedToMe: true,
            alerts: true,
            settings: true
        )
        .observe(on: .global(qos: .utility))
        .on(success: { [weak self] denseSensors in
            guard let sSelf = self else { return }

            let alerts = denseSensors.compactMap { sensor in
                sensor.alerts
            }
            sSelf.alertService.sync(cloudAlerts: alerts)

            let cloudSensors = denseSensors.compactMap { sensor in
                sensor.sensor.any
            }
            let sensors = sSelf.syncSensors(
                cloudSensors: cloudSensors,
                denseSensor: denseSensors
            )
            sensors
                .observe(on: .global(qos: .utility))
                .on(success: { [weak self] updatedSensors in
                    guard let sSelf = self else { return }
                    let filteredDenseSensorsWithoutHistory = denseSensors.filter { sensor in
                        guard let maxHistoryDays = sensor.subscription?.maxHistoryDays
                        else {
                            return false
                        }
                        return maxHistoryDays <= 0
                    }

                    // Store the latest measurement record date for the sensors without history
                    // as the sync date. For the rest this value will be set after successful sync.
                    filteredDenseSensorsWithoutHistory.forEach { [weak self]
                        ruuviTag in
                        self?.ruuviLocalSyncState.setSyncDate(
                            ruuviTag.record?.date,
                            for: ruuviTag.sensor.ruuviTagSensor.macId
                        )
                    }

                    let syncLatestPoint = denseSensors.map {
                        sSelf.updateLatestRecord(
                            ruuviTag: $0.sensor.ruuviTagSensor,
                            cloudRecord: $0.record
                        )
                    }
                    let addLatestPointToHistory = denseSensors.map {
                        sSelf.addLatestRecordToHistory(
                            ruuviTag: $0.sensor.ruuviTagSensor,
                            cloudRecord: $0.record
                        )
                    }

                    Future.zip(syncLatestPoint)
                        .observe(on: .global(qos: .utility))
                        .on(success: { _ in
                            Future.zip(addLatestPointToHistory)
                                .observe(on: .global(qos: .utility))
                                .on(success: { _ in
                                    if sSelf.ruuviLocalSettings.historySyncLegacy ||
                                        sSelf.ruuviLocalSettings.historySyncOnDashboard {
                                        sSelf.syncAllHistory()
                                            .observe(on: .global(qos: .utility))
                                            .on(success: { _ in
                                                promise.succeed(value: updatedSensors)
                                            }, failure: { error in
                                                promise.fail(error: error)
                                            })
                                    } else {
                                        promise.succeed(value: updatedSensors)
                                    }
                                }, failure: { error in
                                    promise.fail(error: error)
                                })
                        }, failure: { error in
                            promise.fail(error: error)
                        })
                })
        }, failure: { [weak self] error in
            switch error {
            case .api(.api(.erUnauthorized)):
                self?.postNotification()
            default:
                promise.fail(error: .ruuviCloud(error))
            }
        })
        return promise.future
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func syncSensors(
        cloudSensors: [AnyCloudSensor],
        denseSensor: [RuuviCloudSensorDense]
    ) -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError> {
        let promise = Promise<Set<AnyRuuviTagSensor>, RuuviServiceError>()
        var updatedSensors = Set<AnyRuuviTagSensor>()
        ruuviStorage.readAll()
            .observe(on: .global(qos: .utility))
            .on(success: { [weak self]
                localSensors in
                guard let self else { return }
                let updateSensors: [Future<Bool, RuuviPoolError>] = localSensors
                    .compactMap { localSensor in
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
                                self.ruuviLocalSyncState.setDownloadFullHistory(
                                    for: localSensor.macId,
                                    downloadFull: true
                                )
                            }

                            // Collision handling: Compare timestamps
                            let cloudTimestamp = cloudSensor.lastUpdated ?? 0
                            let localTimestamp = localSensor.lastUpdated ?? 0

                            if localTimestamp > cloudTimestamp && localSensor.isOwner {
                                // Local is newer - queue request to push local name to cloud
                                self.queueSensorNameUpdateToCloud(localSensor: localSensor)
                                // Still update local with non-timestamp cloud data (owner, plan, etc.)
                                // but preserve local name
                                return self.ruuviPool.update(
                                    localSensor.withCloudMetadata(from: cloudSensor)
                                )
                            } else {
                                // Cloud is newer or equal - update local with cloud data
                                return self.ruuviPool.update(localSensor.with(cloudSensor: cloudSensor))
                            }
                        } else {
                            let unclaimed = localSensor.unclaimed()
                            // If there is a local sensor which is unclaimed insert it to the list
                            if unclaimed.any != localSensor {
                                updatedSensors.insert(localSensor)
                                return self.ruuviPool.update(unclaimed)
                            } else {
                                // If there is a local sensor which is claimed and deleted from the cloud,
                                // delete it from local storage
                                // Otherwise keep it stored
                                if localSensor.isCloud {
                                    self.ruuviLocalSyncState.setDownloadFullHistory(
                                        for: localSensor.macId,
                                        downloadFull: nil
                                    )
                                    return self.ruuviPool.delete(localSensor)
                                } else {
                                    return nil
                                }
                            }
                        }
                    }
                let createSensors: [Future<Bool, RuuviPoolError>] = cloudSensors
                    .filter { cloudSensor in
                        !localSensors.contains(where: {
                            $0.id.isLast3BytesEqual(to: cloudSensor.id)
                        })
                    }.map { newCloudSensor in
                        let newLocalSensor = newCloudSensor.ruuviTagSensor
                        updatedSensors.insert(newLocalSensor.any)
                        return self.ruuviPool.create(newLocalSensor)
                    }

                let syncImages = cloudSensors
                    .filter { !self.ruuviLocalImages.isPictureCached(for: $0) }
                    .map { self.syncImage(sensor: $0) }

                Future.zip([Future.zip(createSensors), Future.zip(updateSensors)])
                    .observe(on: .global(qos: .utility))
                    .on(success: { _ in

                        Future.zip(syncImages).observe(on: .global(qos: .utility)).on()

                        let syncSubscriptions = self.subscriptionSyncs(
                            cloudSensors: denseSensor,
                            updatedSensors: updatedSensors
                        )
                        let syncOffsets = self.offsetSyncs(
                            cloudSensors: cloudSensors,
                            updatedSensors: updatedSensors
                        )
                        let displaySettingsSyncs = self.displaySettingsSyncs(
                            denseSensors: denseSensor
                        )
                        let combinedSettingsSyncs = syncOffsets + displaySettingsSyncs

                        Future.zip(syncSubscriptions)
                            .observe(on: .global(qos: .utility))
                            .on(success: { _ in
                                Future.zip(combinedSettingsSyncs)
                                    .observe(on: .global(qos: .utility))
                                    .on(success: { _ in
                                        promise.succeed(value: updatedSensors)
                                    }, failure: { error in
                                        promise.fail(error: .ruuviPool(error))
                                    })
                            }, failure: { error in
                                promise.fail(error: .ruuviPool(error))
                            })

                    }, failure: { error in
                        promise.fail(error: .ruuviPool(error))
                    })
            }, failure: { error in
                promise.fail(error: .ruuviStorage(error))
            })
        return promise.future
    }

    // This method updates the latest data table if a record already exists for the mac address.
    // Otherwise it creates a new record.
    // swiftlint:disable:next function_body_length
    private func updateLatestRecord(
        ruuviTag: RuuviTagSensor,
        cloudRecord: RuuviTagSensorRecord?
    )
    -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        guard let cloudRecord
        else {
            // If there's no cloud record return
            // It is possible that a sensor doesn't have a record if it's a few years old
            ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
            promise.succeed(value: false)
            return promise.future
        }

        // First update the version number of the tag if there is a difference between
        // cloud data and local data.
        if cloudRecord.version > 0 && cloudRecord.version != ruuviTag.version {
            ruuviPool.update(ruuviTag.with(version: cloudRecord.version))
        }

        ruuviStorage.readLatest(ruuviTag)
            .observe(on: .global(qos: .utility))
            .on(
                success: { [weak self] record in
                    guard let sSelf = self else { return }
                    // If the latest table already have a data point for the mac update that record
                    if let record, record.macId != nil,
                       record.macId?.any == cloudRecord.macId?.any {
                        // Store cloud point only if the cloud data is newer than the local data
                        let isMeasurementNew = cloudRecord.date > record.date
                        if sSelf.ruuviLocalSettings.cloudModeEnabled || isMeasurementNew {
                            let recordWithId = cloudRecord.with(macId: record.macId!.any)
                            sSelf.ruuviPool.updateLast(recordWithId)
                                .observe(on: .global(qos: .utility))
                                .on(
                                    success: { _ in
                                        sSelf.ruuviLocalSyncState
                                            .setSyncStatusLatestRecord(
                                                .complete,
                                                for: ruuviTag.id.mac
                                            )
                                        promise.succeed(value: true)
                                    },
                                    failure: { error in
                                        sSelf.ruuviLocalSyncState
                                            .setSyncStatusLatestRecord(
                                                .onError,
                                                for: ruuviTag.id.mac
                                            )
                                    promise.fail(error: .ruuviPool(error))
                                })
                        } else {
                            sSelf.ruuviLocalSyncState.setSyncStatusLatestRecord(.complete, for: ruuviTag.id.mac)
                            promise.succeed(value: false)
                        }
                    } else {
                        // If no record found, create a new record
                        self?.ruuviPool.createLast(cloudRecord)
                            .observe(on: .global(qos: .utility))
                            .on(
                                success: { [weak self] _ in
                                    self?.ruuviLocalSyncState
                                        .setSyncStatusLatestRecord(
                                            .complete,
                                            for: ruuviTag.id.mac
                                        )
                                    promise.succeed(value: true)
                                },
                                failure: { [weak self] error in
                                    self?.ruuviLocalSyncState
                                        .setSyncStatusLatestRecord(
                                            .onError,
                                            for: ruuviTag.id.mac
                                        )
                                    promise.fail(error: .ruuviPool(error))
                                })
                    }
                },
                failure: { [weak self] error in
                self?.ruuviLocalSyncState.setSyncStatusLatestRecord(.onError, for: ruuviTag.id.mac)
                promise.fail(error: .ruuviStorage(error))
            })

        return promise.future
    }

    /// This method writes the latest data point to the history/records table
    private func addLatestRecordToHistory(
        ruuviTag: RuuviTagSensor,
        cloudRecord: RuuviTagSensorRecord?
    )
    -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        guard let cloudRecord
        else {
            // If there's no cloud record return
            // It is possible that a sensor doesn't have a record if it's a few years old
            promise.succeed(value: false)
            return promise.future
        }

        ruuviStorage.readLast(ruuviTag)
            .observe(on: .global(qos: .utility))
            .on(success: { [weak self] record in
                guard let sSelf = self else { return }
                let isMeasurementNew = record.map { cloudRecord.date > $0.date } ?? true
                if let localRecordMac = record?.macId?.any,
                    localRecordMac == cloudRecord.macId?.any {
                    let recordWithId = cloudRecord.with(macId: localRecordMac)
                    if sSelf.ruuviLocalSettings.cloudModeEnabled || isMeasurementNew {
                        sSelf.createAndCompletePromise(with: recordWithId, promise: promise)
                    } else {
                        promise.succeed(value: false)
                    }
                } else {
                    promise.succeed(value: false)
                }
            }, failure: { [weak self] _ in
                if let macId = ruuviTag.macId {
                    let recordWithId = cloudRecord.with(macId: macId.any)
                    self?.createAndCompletePromise(with: recordWithId, promise: promise)
                } else {
                    self?.createAndCompletePromise(with: cloudRecord, promise: promise)
                }
            })
        return promise.future
    }

    private func createAndCompletePromise(
        with cloudRecord: RuuviTagSensorRecord,
        promise: Promise<Bool, RuuviServiceError>
    ) {
        ruuviPool.create(cloudRecord).on(completion: {
            promise.succeed(value: true)
        })
    }

    @discardableResult
    public func syncQueuedRequest(request: RuuviCloudQueuedRequest) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        ruuviCloud.executeQueuedRequest(from: request)
            .observe(on: .global(qos: .utility))
            .on(success: { [weak self] success in
                self?.ruuviPool.deleteQueuedRequest(request)
                promise.succeed(value: success)
            }, failure: { [weak self] error in
                switch error {
                case .api(.api(.erConflict)):
                    // We should delete the request from local db when there's
                    // already new data available on the cloud.
                    self?.ruuviPool.deleteQueuedRequest(request)
                    promise.fail(error: .ruuviCloud(error))
                default:
                    promise.fail(error: .ruuviCloud(error))
                }
            })
        return promise.future
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

    // MARK: - Collision Handling Helpers

    /// Queue a request to push local sensor name to cloud when local is newer
    private func queueSensorNameUpdateToCloud(localSensor: RuuviTagSensor) {
        // Only queue if sensor is owned by user (can update)
        guard localSensor.isOwner else { return }

        ruuviCloud.update(name: localSensor.name, for: localSensor)
            .observe(on: .global(qos: .utility))
            .on()
        // Note: RuuviCloudPure.update(name:for:) already handles creating
        // queued request on failure internally
    }

    /// Queue a request to push local offsets to cloud when local is newer
    private func queueOffsetUpdateToCloud(
        localSensor: RuuviTagSensor,
        localSettings: SensorSettings
    ) {
        // Only queue if sensor is owned by user (can update)
        guard localSensor.isOwner else { return }

        ruuviCloud.update(
            temperatureOffset: localSettings.temperatureOffset,
            humidityOffset: localSettings.humidityOffset != nil
                ? localSettings.humidityOffset! * 100 // Convert to cloud format
                : nil,
            pressureOffset: localSettings.pressureOffset != nil
                ? localSettings.pressureOffset! * 100 // Convert to cloud format
                : nil,
            for: localSensor
        )
        .observe(on: .global(qos: .utility))
        .on()
        // Note: RuuviCloudPure.update(offsets:for:) already handles creating
        // queued request on failure internally
    }

    /// Queue a request to push local display order settings to cloud when local is newer
    private func queueDisplaySettingsToCloud(
        localSensor: RuuviTagSensor,
        displayOrder: [String]
    ) {
        // Only queue if sensor is owned by user (can update)
        guard localSensor.isOwner else { return }

        let types = ["displayOrder"]
        let values = [displayOrder.joined(separator: ",")]

        ruuviCloud.updateSensorSettings(
            for: localSensor,
            types: types,
            values: values,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        .observe(on: .global(qos: .utility))
        .on()
        // Note: RuuviCloudPure.updateSensorSettings already handles creating
        // queued request on failure internally
    }

    /// Queue a request to push local default display order to cloud when local is newer
    private func queueDefaultDisplayOrderToCloud(
        localSensor: RuuviTagSensor,
        defaultDisplayOrder: Bool
    ) {
        // Only queue if sensor is owned by user (can update)
        guard localSensor.isOwner else { return }

        let types = ["defaultDisplayOrder"]
        let values = [defaultDisplayOrder ? "true" : "false"]

        ruuviCloud.updateSensorSettings(
            for: localSensor,
            types: types,
            values: values,
            timestamp: Int(Date().timeIntervalSince1970)
        )
        .observe(on: .global(qos: .utility))
        .on()
        // Note: RuuviCloudPure.updateSensorSettings already handles creating
        // queued request on failure internally
    }
}
