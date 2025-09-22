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
        ruuviUser.logout()
        do {
            let localSensors = try await storage.readAll()
            let sensorsToDelete = localSensors.filter { $0.isClaimed || $0.isCloud }
            if sensorsToDelete.isEmpty {
                clearGlobalSettings()
                postNotification()
                return true
            }

            // Perform cleanup + deletions concurrently
            try await withThrowingTaskGroup(of: Void.self) { group in
                for sensor in sensorsToDelete {
                    // Local synchronous cleanup before async deletes
                    await cleanupSensorData(for: sensor)
                    group.addTask { [pool] in
                        try await pool.delete(sensor)
                    }
                    group.addTask { [pool] in
                        try await pool.deleteAllRecords(sensor.id)
                    }
                    group.addTask { [pool] in
                        try await pool.deleteLast(sensor.id)
                    }
                }
                // Global queued requests deletion
                group.addTask { [pool] in
                    try await pool.deleteQueuedRequests()
                }
                // Drain
                try await group.waitForAll()
            }

            clearGlobalSettings()
            postNotification()
            return true
        } catch let error as RuuviStorageError {
            throw RuuviServiceError.ruuviStorage(error)
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        } catch {
            throw error
        }
    }
}

private extension RuuviServiceAuthImpl {
    func cleanupSensorData(for sensor: RuuviTagSensor) async {
        // Remove custom image
        await propertiesService.removeImage(for: sensor)

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
}
