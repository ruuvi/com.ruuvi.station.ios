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

        return try await RuuviServiceError.perform {
            let localSensors = try await self.storage.readAll()
            let sensorsToDelete = localSensors.filter { $0.isClaimed || $0.isCloud }

            guard !sensorsToDelete.isEmpty else {
                self.clearGlobalSettings()
                self.postLogoutCompletion(success: true)
                self.postNotification()
                return true
            }

            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for sensor in sensorsToDelete {
                        self.cleanupSensorData(for: sensor)
                        group.addTask {
                            _ = try await self.pool.delete(sensor)
                        }
                        group.addTask {
                            _ = try await self.pool.deleteAllRecords(sensor.id)
                        }
                        group.addTask {
                            _ = try await self.pool.deleteLast(sensor.id)
                        }
                    }

                    group.addTask {
                        _ = try await self.pool.deleteQueuedRequests()
                    }

                    for try await _ in group {}
                }

                self.clearGlobalSettings()
                self.postLogoutCompletion(success: true)
                self.postNotification()
                return true
            } catch {
                self.postLogoutCompletion(success: false)
                throw error
            }
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
            localSyncState.setAutoGattSyncAttemptDate(nil, for: macId)
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
