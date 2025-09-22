import Foundation
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
        settings: RuuviLocalSettings
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
    }

    @discardableResult
    public func loadShared(for sensor: RuuviTagSensor) async throws -> Set<AnyShareableSensor> {
        do { return try await cloud.loadShared(for: sensor) } catch { throw error }
    }

    @discardableResult
    public func share(
        macId: MACIdentifier,
        with email: String
    ) async throws -> ShareSensorResponse {
        do { return try await cloud.share(macId: macId, with: email) } catch { throw error }
    }

    @discardableResult
    public func unshare(macId: MACIdentifier, with email: String?) async throws -> MACIdentifier {
        do { return try await cloud.unshare(macId: macId, with: email) } catch { throw error }
    }

    @discardableResult
    public func claim(sensor: RuuviTagSensor) async throws -> AnyRuuviTagSensor {
        guard let macId = sensor.macId else { throw RuuviServiceError.macIdIsNil }
        guard let owner = ruuviUser.email else { throw RuuviServiceError.ruuviCloud(.notAuthorized) }
        do {
            _ = try await cloud.claim(name: sensor.name, macId: macId)
            return try await handleSensorClaimed(sensor: sensor, owner: owner, macId: macId)
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        } catch {
            throw error
        }
    }

    @discardableResult
    public func contest(
        sensor: RuuviTagSensor,
        secret: String
    ) async throws -> AnyRuuviTagSensor {
        guard let macId = sensor.macId else { throw RuuviServiceError.macIdIsNil }
        guard let owner = ruuviUser.email else { throw RuuviServiceError.ruuviCloud(.notAuthorized) }
        do {
            _ = try await cloud.contest(macId: macId, secret: secret)
            return try await handleSensorClaimed(sensor: sensor, owner: owner, macId: macId)
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        } catch {
            throw error
        }
    }

    @discardableResult
    public func unclaim(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) async throws -> AnyRuuviTagSensor {
        guard let macId = sensor.macId else { throw RuuviServiceError.macIdIsNil }
        do {
            _ = try await cloud.unclaim(macId: macId, removeCloudHistory: removeCloudHistory)
            let unclaimedSensor = sensor
                .with(isClaimed: false)
                .with(canShare: false)
                .with(sharedTo: [])
                .with(isCloudSensor: false)
                .withoutOwner()
            _ = try await pool.update(unclaimedSensor)
            return unclaimedSensor.any
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        } catch {
            throw error
        }
    }

    @discardableResult
    public func add(
        sensor: RuuviTagSensor,
        record: RuuviTagSensorRecord
    ) async throws -> AnyRuuviTagSensor {
        do {
            try await pool.create(sensor)
            async let rec = pool.create(record)
            async let last = pool.createLast(record)
            _ = try await (rec, last)
            return sensor.any
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        } catch { throw error }
    }

    @discardableResult
    public func remove(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) async throws -> AnyRuuviTagSensor {
        do {
            if let macId = sensor.macId, sensor.isCloud {
                if sensor.isOwner {
                    _ = try await unclaim(sensor: sensor, removeCloudHistory: removeCloudHistory)
                } else {
                    _ = try await unshare(macId: macId, with: nil)
                }
            }
            await propertiesService.removeImage(for: sensor)
            cleanupSensorData(for: sensor)
            async let a = pool.delete(sensor)
            async let b = pool.deleteAllRecords(sensor.id)
            async let c = pool.deleteLast(sensor.id)
            _ = try await (a, b, c)
            try await checkAndClearGlobalSettings()
            return sensor.any
        } catch let error as RuuviPoolError { throw RuuviServiceError.ruuviPool(error) }
    }

    @discardableResult
    public func checkOwner(macId: MACIdentifier) async throws -> String? {
        do { return try await cloud.checkOwner(macId: macId) } catch { throw error }
    }

    @discardableResult
    public func updateShareable(for sensor: RuuviTagSensor) async throws -> Bool {
        do { return try await pool.update(sensor) } catch let error as RuuviPoolError { throw RuuviServiceError.ruuviPool(error) }
    }
}

extension RuuviServiceOwnershipImpl {
    private func handleSensorClaimed(
        sensor: RuuviTagSensor,
        owner: String,
        macId: MACIdentifier
    ) async throws -> AnyRuuviTagSensor {
        let claimedSensor = sensor
            .with(owner: owner)
            .with(isClaimed: true)
            .with(isCloudSensor: true)
            .with(isOwner: true)
        _ = try await pool.update(claimedSensor)
        return try await handleUpdatedSensor(sensor: claimedSensor, macId: macId)
    }

    private func handleUpdatedSensor(
        sensor: RuuviTagSensor,
        macId: MACIdentifier
    ) async throws -> AnyRuuviTagSensor {
        if let customImage = localImages.getCustomBackground(for: macId) {
            guard let jpegData = customImage.jpegData(compressionQuality: 1.0) else {
                throw RuuviServiceError.failedToGetJpegRepresentation
            }
            _ = try await cloud.upload(imageData: jpegData, mimeType: .jpg, progress: nil, for: macId)
        }

        // Fire and forget updating offsets (no need to block claim path)
        Task { [cloud, storage] in
            let settings = try? await storage.readSensorSettings(sensor)
            _ = try? await cloud.update(
                temperatureOffset: settings?.temperatureOffset ?? 0,
                humidityOffset: (settings?.humidityOffset ?? 0) * 100,
                pressureOffset: (settings?.pressureOffset ?? 0) * 100,
                for: sensor
            )
        }

        AlertType.allCases.forEach { type in
            if let alert = alertService.alert(for: sensor, of: type) {
                alertService.register(type: alert, ruuviTag: sensor)
            }
        }
        return sensor.any
    }

    private func cleanupSensorData(for sensor: RuuviTagSensor) {
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

    private func checkAndClearGlobalSettings() async throws {
        let sensors = try await storage.readAll()
        if sensors.isEmpty { localSyncState.setSyncDate(nil) }
    }
}
