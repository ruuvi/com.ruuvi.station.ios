#if SWIFT_PACKAGE
    import RuuviService
#endif
// swiftlint:disable file_length

import Foundation
import UIKit
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviStorage
import RuuviUser

public extension Notification.Name {
    static let RuuviTagOwnershipCheckDidEnd = Notification.Name("RuuviTagOwnershipCheckDidEnd")
}

public enum RuuviTagOwnershipCheckResultKey: String {
    case hasOwner = "hasTagOwner"
}

// swiftlint:disable:next type_body_length
public final class RuuviServiceOwnershipImpl: RuuviServiceOwnership {
    private let cloud: RuuviCloud
    private let pool: RuuviPool
    private let propertiesService: RuuviServiceSensorProperties
    private let localIDs: RuuviLocalIDs
    private let localImages: RuuviLocalImages
    private let storage: RuuviStorage
    private let alertService: RuuviServiceAlert
    private let ruuviUser: RuuviUser
    private let localSyncState: RuuviLocalSyncState
    private let settings: RuuviLocalSettings
    private let gattService: GATTService
    private let backgroundTasks = RuuviTaskStore()

    public init(
        cloud: RuuviCloud,
        pool: RuuviPool,
        propertiesService: RuuviServiceSensorProperties,
        localIDs: RuuviLocalIDs,
        localImages: RuuviLocalImages,
        storage: RuuviStorage,
        alertService: RuuviServiceAlert,
        ruuviUser: RuuviUser,
        localSyncState: RuuviLocalSyncState,
        settings: RuuviLocalSettings,
        gattService: GATTService
    ) {
        self.cloud = cloud
        self.pool = pool
        self.propertiesService = propertiesService
        self.localIDs = localIDs
        self.localImages = localImages
        self.storage = storage
        self.alertService = alertService
        self.ruuviUser = ruuviUser
        self.localSyncState = localSyncState
        self.settings = settings
        self.gattService = gattService
    }

    @MainActor
    public func loadShared(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> Set<AnyShareableSensor> {
        do { return try await cloud.loadShared(for: sensor) } catch { throw .ruuviCloud(error) }
    }

    @MainActor
    public func share(macId: MACIdentifier, with email: String) async throws(RuuviServiceError) -> ShareSensorResponse {
        do { return try await cloud.share(macId: macId, with: email) } catch { throw .ruuviCloud(error) }
    }

    @MainActor
    public func unshare(macId: MACIdentifier, with email: String?) async throws(RuuviServiceError) -> MACIdentifier {
        do { return try await cloud.unshare(macId: macId, with: email) } catch { throw .ruuviCloud(error) }
    }

    @MainActor
    public func claim(sensor: RuuviTagSensor) async throws(RuuviServiceError) -> AnyRuuviTagSensor {
        guard let mac = sensor.macId else { throw .macIdIsNil }
        guard let owner = ruuviUser.email else { throw .ruuviCloud(.notAuthorized) }
        let canonical = try await ensureFullMac(for: sensor)
        do { _ = try await cloud.claim(name: sensor.name, macId: canonical) } catch { throw .ruuviCloud(error) }
        return try await handleSensorClaimed(sensor: sensor, owner: owner, macId: mac)
    }

    @MainActor
    public func contest(sensor: RuuviTagSensor, secret: String) async throws(RuuviServiceError) -> AnyRuuviTagSensor {
        guard let mac = sensor.macId else { throw .macIdIsNil }
        guard let owner = ruuviUser.email else { throw .ruuviCloud(.notAuthorized) }
        let canonical = try await ensureFullMac(for: sensor)
        do { _ = try await cloud.contest(macId: canonical, secret: secret) } catch { throw .ruuviCloud(error) }
        return try await handleSensorClaimed(sensor: sensor, owner: owner, macId: mac)
    }

    @MainActor
    public func unclaim(sensor: RuuviTagSensor, removeCloudHistory: Bool) async throws(RuuviServiceError)
        -> AnyRuuviTagSensor
    {
        let mac = try await ensureFullMac(for: sensor)
        do { _ = try await cloud.unclaim(macId: mac, removeCloudHistory: removeCloudHistory) } catch {
            throw .ruuviCloud(error)
        }
        let updated = sensor.with(isClaimed: false).with(canShare: false).with(sharedTo: [])
            .with(sharedToPending: []).with(isCloudSensor: false).withoutOwner()
        do { _ = try await pool.update(updated) } catch { throw .ruuviPool(error) }
        return updated.any
    }

    @MainActor
    public func add(sensor: RuuviTagSensor, record: RuuviTagSensorRecord?) async throws(RuuviServiceError)
        -> AnyRuuviTagSensor
    {
        let updated = sensor.with(lastUpdated: Date())
        do {
            _ = try await pool.create(updated)
            if let record {
                _ = try await pool.create(record.with(source: .advertisement))
                _ = try await pool.createLast(record.with(source: .advertisement))
            }
        } catch { throw .ruuviPool(error) }
        return updated.any
    }

    @MainActor
    public func remove(sensor: RuuviTagSensor, removeCloudHistory: Bool) async throws(RuuviServiceError)
        -> AnyRuuviTagSensor
    {
        let wasSuppressed = await MainActor.run {
            let previous = localSyncState.isAutoGattSyncSuppressed(for: sensor.macId)
            localSyncState.setAutoGattSyncSuppressed(true, for: sensor.macId)
            return previous
        }
        do {
            if let luid = sensor.luid { _ = try await gattService.stopGattSync(for: luid.value) }
            return try await removeStoppedSensor(sensor: sensor, removeCloudHistory: removeCloudHistory)
        } catch {
            await MainActor.run { localSyncState.setAutoGattSyncSuppressed(wasSuppressed, for: sensor.macId) }
            throw error
        }
    }

    @MainActor
    private func removeStoppedSensor(sensor: RuuviTagSensor, removeCloudHistory: Bool) async throws(RuuviServiceError)
        -> AnyRuuviTagSensor
    {
        do {
            _ = try await pool.delete(sensor)
            _ = try await pool.deleteAllRecords(sensor.id)
            _ = try await pool.deleteLast(sensor.id)
            _ = try await pool.deleteSensorSettings(sensor)
        } catch { throw .ruuviPool(error) }
        if let mac = sensor.macId, sensor.isCloud {
            // Preserve local completion while the cloud API handles retries independently.
            backgroundTasks.run(seriallyFor: "remove:" + sensor.id) { @MainActor [self] in
                let canonical = (try? await ensureFullMac(for: sensor)) ?? localIDs.fullMac(for: mac) ?? mac
                if sensor.isOwner {
                    _ = try? await cloud.unclaim(macId: canonical, removeCloudHistory: removeCloudHistory)
                } else {
                    _ = try? await cloud.unshare(macId: canonical, with: nil)
                }
            }
        }
        propertiesService.removeImage(for: sensor)
        cleanupSensorData(for: sensor)
        if let sensors = try? await storage.readAll(), sensors.isEmpty { localSyncState.setSyncDate(nil) }
        return sensor.any
    }

    @MainActor
    public func checkOwner(macId: MACIdentifier) async throws(RuuviServiceError) -> (String?, String?) {
        let result: (String?, String?)
        do { result = try await cloud.checkOwner(macId: macId) } catch { throw .ruuviCloud(error) }
        if let sensorString = result.1 {
            let full = sensorString.lowercased().mac
            localIDs.set(fullMac: full, for: localIDs.originalMac(for: full) ?? macId)
        }
        return result
    }

    @MainActor
    public func updateShareable(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> Bool {
        do { _ = try await pool.update(sensor); return true } catch { throw .ruuviPool(error) }
    }

    @MainActor
    private func handleSensorClaimed(sensor: RuuviTagSensor, owner: String, macId: MACIdentifier)
        async throws(RuuviServiceError) -> AnyRuuviTagSensor
    {
        let claimed = sensor.with(owner: owner).with(isClaimed: true).with(isCloudSensor: true).with(isOwner: true)
        do { _ = try await pool.update(claimed) } catch { throw .ruuviPool(error) }
        if let settings = try? await storage.readSensorSettings(claimed) {
            _ = try? await cloud.update(
                temperatureOffset: settings.temperatureOffset ?? 0,
                humidityOffset: (settings.humidityOffset ?? 0) * 100,
                pressureOffset: (settings.pressureOffset ?? 0) * 100,
                for: claimed
            )
        }
        for type in AlertType.allCases {
            if let alert = alertService.alert(for: claimed, of: type) {
                alertService.register(type: alert, ruuviTag: claimed)
            }
        }
        if let background = localCustomBackground(for: claimed) {
            guard let data = background.jpegData(compressionQuality: 1) else { throw .failedToGetJpegRepresentation }
            do { _ = try await cloud.upload(imageData: data, mimeType: .jpg, progress: nil, for: macId) } catch {
                throw .ruuviCloud(error)
            }
        }
        return claimed.any
    }

    @MainActor
    private func ensureFullMac(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> MACIdentifier {
        guard let mac = sensor.macId else { throw .macIdIsNil }
        let stored = localIDs.fullMac(for: mac)
        if RuuviDataFormat.dataFormat(from: sensor.version) == .v6, mac.value.needsFullMacLookup, stored == nil {
            let result = try await checkOwner(macId: mac)
            if let value = result.1 { return value.lowercased().mac }
        }
        return stored ?? mac
    }

    private func localCustomBackground(for sensor: RuuviTagSensor) -> UIImage? {
        if let macId = sensor.macId,
            let image = localImages.getCustomBackground(for: macId)
        {
            return image
        }
        if let luid = sensor.luid,
            let image = localImages.getCustomBackground(for: luid)
        {
            return image
        }
        return nil
    }

    private func cleanupSensorData(for sensor: RuuviTagSensor) {
        // Clean up sync state data
        if let macId = sensor.macId {
            localSyncState.setSyncDate(nil, for: macId)
            localSyncState.setGattSyncDate(nil, for: macId)
            localSyncState.setAutoGattSyncAttemptDate(nil, for: macId)

            settings.setOwnerCheckDate(for: macId, value: nil)

            // Clean up widget card reference if it matches this sensor
            if let currentCardMacId = settings.cardToOpenFromWidget(),
                currentCardMacId == macId.value
            {
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
        settings.setShowCustomCO2AlertBound(false, for: sensor.id)
        settings.setShowCustomPMAlertBound(false, for: sensor.id)

        // Clean up last opened chart if it matches this sensor
        if let lastChart = settings.lastOpenedChart(),
            lastChart == sensor.id
        {
            settings.setLastOpenedChart(with: nil)
        }

        // Remove all alert types for this sensor
        AlertType.allCases.forEach { type in
            alertService.remove(type: type, ruuviTag: sensor)
        }
    }

}

private extension String {
    var needsFullMacLookup: Bool {
        let hexDigits = unicodeScalars.filter {
            CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0)
        }.count
        return hexDigits < 12
    }
}
// swiftlint:enable file_length
