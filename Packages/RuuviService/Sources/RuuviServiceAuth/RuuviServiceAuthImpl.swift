import Foundation
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

    public func logout() async throws -> Bool {
        NotificationCenter
            .default
            .post(name: .RuuviAuthServiceWillLogout, object: self, userInfo: nil)
        ruuviUser.logout()

        do {
            let localSensors = try await storage.readAll()
            let sensorsToDelete = localSensors.filter { $0.isClaimed || $0.isCloud }
            guard !sensorsToDelete.isEmpty else {
                // Clear global settings even if no sensors to delete
                clearGlobalSettings()
                postLogoutCompletion(success: true)
                postNotification()
                return true
            }

            var operations: [() async throws -> Bool] = []
            for sensor in sensorsToDelete {
                operations.append { try await self.pool.delete(sensor) }
                operations.append { try await self.pool.deleteAllRecords(sensor.id) }
                operations.append { try await self.pool.deleteLast(sensor.id) }

                // Perform comprehensive synchronous cleanup
                cleanupSensorData(for: sensor)
            }

            // Add the global deleteQueuedRequests operation
            operations.append { try await self.pool.deleteQueuedRequests() }

            try await withThrowingTaskGroup(of: Void.self) { group in
                for operation in operations {
                    group.addTask {
                        _ = try await operation()
                    }
                }
                try await group.waitForAll()
            }

            // Clear any remaining global settings
            clearGlobalSettings()
            postLogoutCompletion(success: true)
            postNotification()
            return true
        } catch let error as RuuviPoolError {
            postLogoutCompletion(success: false)
            throw RuuviServiceError.ruuviPool(error)
        } catch let error as RuuviStorageError {
            postLogoutCompletion(success: false)
            throw RuuviServiceError.ruuviStorage(error)
        } catch {
            postLogoutCompletion(success: false)
            throw RuuviServiceError.networking(error)
        }
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
