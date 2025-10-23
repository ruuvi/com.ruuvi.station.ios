import Foundation
import Future
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviStorage
import RuuviUser

public final class RuuviServiceAuthImpl: RuuviServiceAuth {
    private let ruuviUser: RuuviUser
    private let pool: RuuviPool
    private let storage: RuuviStorage
    private let propertiesService: RuuviServiceSensorProperties
    private let localIDs: RuuviLocalIDs
    private let localSyncState: RuuviLocalSyncState
    private let alertService: RuuviServiceAlert
    private let settings: RuuviLocalSettings

    public init(
        ruuviUser: RuuviUser,
        pool: RuuviPool,
        storage: RuuviStorage,
        propertiesService: RuuviServiceSensorProperties,
        localIDs: RuuviLocalIDs,
        localSyncState: RuuviLocalSyncState,
        alertService: RuuviServiceAlert,
        settings: RuuviLocalSettings
    ) {
        self.ruuviUser = ruuviUser
        self.pool = pool
        self.storage = storage
        self.propertiesService = propertiesService
        self.localIDs = localIDs
        self.localSyncState = localSyncState
        self.alertService = alertService
        self.settings = settings
    }

    public func logout() -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        NotificationCenter
            .default
            .post(name: .RuuviAuthServiceWillLogout, object: self, userInfo: nil)
        ruuviUser.logout()

        storage.readAll()
            .on(success: { [weak self] localSensors in
                guard let sSelf = self else {
                    return
                }

                let sensorsToDelete = localSensors.filter { $0.isClaimed || $0.isCloud }
                guard !sensorsToDelete.isEmpty else {
                    // Clear global settings even if no sensors to delete
                    sSelf.clearGlobalSettings()
                    promise.succeed(value: true)
                    sSelf.postLogoutCompletion(success: true)
                    sSelf.postNotification()
                    return
                }

                // Collect all individual operations from all sensors
                var allOperations: [Future<Bool, RuuviPoolError>] = []

                for sensor in sensorsToDelete {
                    let deleteSensorOperation = sSelf.pool.delete(sensor)
                    let deleteRecordsOperation = sSelf.pool.deleteAllRecords(sensor.id)
                    let deleteLatestRecordOperation = sSelf.pool.deleteLast(sensor.id)

                    allOperations.append(deleteSensorOperation)
                    allOperations.append(deleteRecordsOperation)
                    allOperations.append(deleteLatestRecordOperation)

                    // Perform comprehensive synchronous cleanup
                    sSelf.cleanupSensorData(for: sensor)
                }

                // Add the global deleteQueuedRequests operation
                allOperations.append(sSelf.pool.deleteQueuedRequests())

                // Wait for all operations to complete
                Future.zip(allOperations)
                    .on(success: { _ in
                        // Clear any remaining global settings
                        sSelf.clearGlobalSettings()
                        promise.succeed(value: true)
                        sSelf.postLogoutCompletion(success: true)
                        sSelf.postNotification()
                    }, failure: { error in
                        sSelf.postLogoutCompletion(success: false)
                        promise.fail(error: .ruuviPool(error))
                    })

            }, failure: { [weak self]error in
                self?.postLogoutCompletion(success: false)
                promise.fail(error: .ruuviStorage(error))
            })

        return promise.future
    }
}

private extension RuuviServiceAuthImpl {
    func cleanupSensorData(for sensor: RuuviTagSensor) {
        // Remove custom image
        propertiesService.removeImage(for: sensor)

        // Clean up sync state data
        if let macId = sensor.macId {
            localSyncState.setSyncDate(nil, for: macId)
            localSyncState.setGattSyncDate(nil, for: macId)
            settings.setOwnerCheckDate(for: macId, value: nil)

            // Clean up widget card reference if it matches this sensor
            if let currentCardMacId = settings.cardToOpenFromWidget(),
               currentCardMacId == macId.value {
                settings.setCardToOpenFromWidget(for: nil)
            }
        }

        // Clean up dialog states using local identifier
        if let luid = sensor.luid {
            settings.setKeepConnectionDialogWasShown(false, for: luid)
            settings.setFirmwareUpdateDialogWasShown(false, for: luid)
            settings.setSyncDialogHidden(false, for: luid)
        }

        // Clean up sensor-specific settings using sensor ID
        settings.setShowCustomTempAlertBound(false, for: sensor.id)

        // Clean up last opened chart if it matches this sensor
        if let lastChart = settings.lastOpenedChart(),
           lastChart == sensor.id {
            settings.setLastOpenedChart(with: nil)
        }

        // Remove all alert types for this sensor
        AlertType.allCases.forEach { type in
            alertService.remove(type: type, ruuviTag: sensor)
        }
    }

    func clearGlobalSettings() {
        // Clear global sync state
        localSyncState.setSyncDate(nil)

        // Clear global widget and chart settings
        settings.setCardToOpenFromWidget(for: nil)
        settings.setLastOpenedChart(with: nil)
    }

    func postNotification() {
        NotificationCenter
            .default
            .post(name: .RuuviAuthServiceDidLogout, object: self, userInfo: nil)
    }

    func postLogoutCompletion(success: Bool) {
        NotificationCenter
            .default
            .post(
                name: .RuuviAuthServiceLogoutDidFinish,
                object: self,
                userInfo: [RuuviAuthServiceLogoutDidFinishKey.success: success]
            )
    }
}
