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
        do {
            return try await cloud.loadShared(for: sensor)
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func share(
        macId: MACIdentifier,
        with email: String
    ) async throws -> ShareSensorResponse {
        do {
            return try await cloud.share(macId: macId, with: email)
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func unshare(macId: MACIdentifier, with email: String?) async throws -> MACIdentifier {
        do {
            return try await cloud.unshare(macId: macId, with: email)
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        }
    }

    @discardableResult
    public func claim(sensor: RuuviTagSensor) async throws -> AnyRuuviTagSensor {
        guard let macId = sensor.macId else {
            throw RuuviServiceError.macIdIsNil
        }
        guard let owner = ruuviUser.email else {
            throw RuuviServiceError.ruuviCloud(.notAuthorized)
        }

        let canonicalMac = try await ensureFullMac(for: sensor)
        do {
            _ = try await cloud.claim(name: sensor.name, macId: canonicalMac)
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        }

        return try await handleSensorClaimed(
            sensor: sensor,
            owner: owner,
            macId: macId
        )
    }

    @discardableResult
    public func contest(
        sensor: RuuviTagSensor,
        secret: String
    ) async throws -> AnyRuuviTagSensor {
        guard let macId = sensor.macId else {
            throw RuuviServiceError.macIdIsNil
        }
        guard let owner = ruuviUser.email else {
            throw RuuviServiceError.ruuviCloud(.notAuthorized)
        }

        let canonicalMac = try await ensureFullMac(for: sensor)
        do {
            _ = try await cloud.contest(macId: canonicalMac, secret: secret)
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        }

        return try await handleSensorClaimed(
            sensor: sensor,
            owner: owner,
            macId: macId
        )
    }

    @discardableResult
    public func unclaim(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) async throws -> AnyRuuviTagSensor {
        let canonicalMac = try await ensureFullMac(for: sensor)
        do {
            _ = try await cloud.unclaim(
                macId: canonicalMac,
                removeCloudHistory: removeCloudHistory
            )
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        }

        let unclaimedSensor = sensor
            .with(isClaimed: false)
            .with(canShare: false)
            .with(sharedTo: [])
            .with(isCloudSensor: false)
            .withoutOwner()
        do {
            _ = try await pool.update(unclaimedSensor)
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        }
        return unclaimedSensor.any
    }

    @discardableResult
    public func add(
        sensor: RuuviTagSensor,
        record: RuuviTagSensorRecord
    ) async throws -> AnyRuuviTagSensor {
        do {
            async let entity = pool.create(sensor)
            async let recordEntity = pool.create(record)
            async let recordLast = pool.createLast(record)
            _ = try await (entity, recordEntity, recordLast)
            return sensor.any
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        }
    }

    @discardableResult
    public func remove(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) async throws -> AnyRuuviTagSensor {
        var shouldUnclaim = false
        var shouldUnshare = false
        if let _ = sensor.macId,
           sensor.isCloud {
            if sensor.isOwner {
                shouldUnclaim = true
            } else {
                shouldUnshare = true
            }
        }

        // Remove custom image
        propertiesService.removeImage(for: sensor)

        // Clean up all sensor-related local prefs data
        cleanupSensorData(for: sensor)

        do {
            async let deleteTagOperation = pool.delete(sensor)
            async let deleteRecordsOperation = pool.deleteAllRecords(sensor.id)
            async let deleteLastRecordOperation = pool.deleteLast(sensor.id)
            async let deleteSensorSettingsOperation = pool.deleteSensorSettings(sensor)
            _ = try await (
                deleteTagOperation,
                deleteRecordsOperation,
                deleteLastRecordOperation,
                deleteSensorSettingsOperation
            )
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        }

        Task { [weak self] in
            await self?.checkAndClearGlobalSettings()
        }

        if shouldUnclaim {
            Task { [weak self] in
                _ = try? await self?.unclaim(sensor: sensor, removeCloudHistory: removeCloudHistory)
            }
        } else if shouldUnshare, let macId = sensor.macId {
            Task { [weak self] in
                _ = try? await self?.unshare(macId: macId, with: nil)
            }
        }

        return sensor.any
    }

    @discardableResult
    public func checkOwner(macId: MACIdentifier) async throws -> (String?, String?) {
        let result: (String?, String?)
        do {
            result = try await cloud.checkOwner(macId: macId)
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        }

        if let sensorString = result.1 {
            let fullMac = sensorString.lowercased().mac
            let original = await localIDs.originalMac(for: fullMac) ?? macId
            await localIDs.set(fullMac: fullMac, for: original)
        }

        return result
    }

    @discardableResult
    public func updateShareable(for sensor: RuuviTagSensor) async throws -> Bool {
        do {
            _ = try await pool.update(sensor)
            return true
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        }
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
        do {
            _ = try await pool.update(claimedSensor)
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        }

        try await handleUpdatedSensor(sensor: claimedSensor, macId: macId)
        return claimedSensor.any
    }

    private func handleUpdatedSensor(
        sensor: RuuviTagSensor,
        macId: MACIdentifier
    ) async throws {
        Task { [cloud, storage] in
            let settings = try? await storage.readSensorSettings(sensor)
            _ = try? await cloud.update(
                temperatureOffset: settings?.temperatureOffset ?? 0,
                humidityOffset: (settings?.humidityOffset ?? 0) * 100, // fraction local, % on cloud
                pressureOffset: (settings?.pressureOffset ?? 0) * 100, // hPa local, Pa on cloud
                for: sensor
            )
        }

        AlertType.allCases.forEach { type in
            if let alert = alertService.alert(for: sensor, of: type) {
                alertService.register(type: alert, ruuviTag: sensor)
            }
        }

        if let localBackground = localImages.getCustomBackground(for: macId) {
            try await uploadBackground(localBackground, macId: macId)
            return
        }

        if let image = try? await propertiesService.getImage(for: sensor) {
            try await uploadBackground(image, macId: macId)
        }
    }

    private func uploadBackground(
        _ image: UIImage,
        macId: MACIdentifier
    ) async throws {
        guard let jpegData = image.jpegData(compressionQuality: 1.0) else {
            throw RuuviServiceError.failedToGetJpegRepresentation
        }

        do {
            _ = try await cloud.upload(
                imageData: jpegData,
                mimeType: .jpg,
                progress: nil,
                for: macId
            )
        } catch let error as RuuviCloudError {
            throw RuuviServiceError.ruuviCloud(error)
        }
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

    private func checkAndClearGlobalSettings() async {
        let sensors = try? await storage.readAll()
        if sensors?.isEmpty == true {
            localSyncState.setSyncDate(nil)
        }
    }
}

private extension RuuviServiceOwnershipImpl {
    func ensureFullMac(for sensor: RuuviTagSensor) async throws -> MACIdentifier {
        guard let macId = sensor.macId else {
            throw RuuviServiceError.macIdIsNil
        }

        let storedFull = await localIDs.fullMac(for: macId)
        let dataFormat = RuuviDataFormat.dataFormat(from: sensor.version)
        if dataFormat == .v6,
           macId.value.needsFullMacLookup,
           storedFull == nil {
            let result = try await checkOwner(macId: macId)
            if let sensorString = result.1 {
                let fullMac = sensorString.lowercased().mac
                let original = await localIDs.originalMac(for: fullMac) ?? macId
                await localIDs.set(fullMac: fullMac, for: original)
                return fullMac
            }
            return macId
        } else {
            return storedFull ?? macId
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
