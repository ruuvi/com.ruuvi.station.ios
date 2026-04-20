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
        return try await RuuviServiceError.perform {
            try await self.cloud.loadShared(for: sensor)
        }
    }

    @discardableResult
    public func share(
        macId: MACIdentifier,
        with email: String
    ) async throws -> ShareSensorResponse {
        return try await RuuviServiceError.perform {
            try await self.cloud.share(macId: macId, with: email)
        }
    }

    @discardableResult
    public func unshare(macId: MACIdentifier, with email: String?) async throws -> MACIdentifier {
        return try await RuuviServiceError.perform {
            try await self.cloud.unshare(macId: macId, with: email)
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
        _ = try await RuuviServiceError.perform {
            try await self.cloud.claim(name: sensor.name, macId: canonicalMac)
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
        _ = try await RuuviServiceError.perform {
            try await self.cloud.contest(macId: canonicalMac, secret: secret)
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
        _ = try await RuuviServiceError.perform {
            try await self.cloud.unclaim(
                macId: canonicalMac,
                removeCloudHistory: removeCloudHistory
            )
        }
        let unclaimedSensor = sensor
            .with(isClaimed: false)
            .with(canShare: false)
            .with(sharedTo: [])
            .with(isCloudSensor: false)
            .withoutOwner()
        _ = try await RuuviServiceError.perform {
            try await self.pool.update(unclaimedSensor)
        }
        return unclaimedSensor.any
    }

    @discardableResult
    public func add(
        sensor: RuuviTagSensor,
        record: RuuviTagSensorRecord?
    ) async throws -> AnyRuuviTagSensor {
        let updatedSensor = sensor.with(lastUpdated: Date())
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = try await RuuviServiceError.perform {
                    try await self.pool.create(updatedSensor)
                }
            }
            if let record {
                let advertisementRecord = record.with(source: .advertisement)
                // NFC-only adds persist the sensor immediately and attach records later,
                // once the first BT measurement is actually available.
                group.addTask {
                    _ = try await RuuviServiceError.perform {
                        try await self.pool.create(advertisementRecord)
                    }
                }
                group.addTask {
                    _ = try await RuuviServiceError.perform {
                        try await self.pool.createLast(advertisementRecord)
                    }
                }
            }
            for try await _ in group {}
        }
        return updatedSensor.any
    }

    @discardableResult
    public func remove(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) async throws -> AnyRuuviTagSensor {
        let unclaimTask: Task<Void, Never>?
        let unshareTask: Task<Void, Never>?

        if let macId = sensor.macId, sensor.isCloud {
            if sensor.isOwner {
                unclaimTask = Task {
                    _ = try? await self.unclaim(
                        sensor: sensor,
                        removeCloudHistory: removeCloudHistory
                    )
                }
                unshareTask = nil
            } else {
                unclaimTask = nil
                unshareTask = Task {
                    _ = try? await self.unshare(macId: macId, with: nil)
                }
            }
        } else {
            unclaimTask = nil
            unshareTask = nil
        }

        // Remove custom image
        propertiesService.removeImage(for: sensor)

        // Clean up all sensor-related local prefs data
        cleanupSensorData(for: sensor)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = try await RuuviServiceError.perform {
                    try await self.pool.delete(sensor)
                }
            }
            group.addTask {
                _ = try await RuuviServiceError.perform {
                    try await self.pool.deleteAllRecords(sensor.id)
                }
            }
            group.addTask {
                _ = try await RuuviServiceError.perform {
                    try await self.pool.deleteLast(sensor.id)
                }
            }
            group.addTask {
                _ = try await RuuviServiceError.perform {
                    try await self.pool.deleteSensorSettings(sensor)
                }
            }
            for try await _ in group {}
        }

        await unclaimTask?.value
        await unshareTask?.value
        checkAndClearGlobalSettings()
        return sensor.any
    }

    @discardableResult
    public func checkOwner(macId: MACIdentifier) async throws -> (String?, String?) {
        let result = try await RuuviServiceError.perform {
            try await self.cloud.checkOwner(macId: macId)
        }
        if let sensorString = result.1 {
            let fullMac = sensorString.lowercased().mac
            let original = self.localIDs.originalMac(for: fullMac) ?? macId
            self.localIDs.set(fullMac: fullMac, for: original)
        }
        return result
    }

    @discardableResult
    public func updateShareable(for sensor: RuuviTagSensor) async throws -> Bool {
        _ = try await RuuviServiceError.perform {
            try await self.pool.update(sensor)
        }
        return true
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
        _ = try await RuuviServiceError.perform {
            try await self.pool.update(claimedSensor)
        }
        return try await handleUpdatedSensor(
            sensor: claimedSensor,
            macId: macId
        )
    }

    private func handleUpdatedSensor(
        sensor: RuuviTagSensor,
        macId: MACIdentifier
    ) async throws -> AnyRuuviTagSensor {
        Task { [weak self] in
            guard let self else { return }
            let settings = try? await self.storage.readSensorSettings(sensor)
            Task {
                _ = try? await self.cloud.update(
                    temperatureOffset: settings?.temperatureOffset ?? 0,
                    humidityOffset: (settings?.humidityOffset ?? 0) * 100, // fraction local, % on cloud
                    pressureOffset: (settings?.pressureOffset ?? 0) * 100, // hPa local, Pa on cloud
                    for: sensor
                )
            }
        }

        AlertType.allCases.forEach { type in
            if let alert = alertService.alert(for: sensor, of: type) {
                alertService.register(type: alert, ruuviTag: sensor)
            }
        }

        func uploadBackground(_ image: UIImage) async throws {
            guard let jpegData = image.jpegData(compressionQuality: 1.0) else {
                throw RuuviServiceError.failedToGetJpegRepresentation
            }
            _ = try await RuuviServiceError.perform {
                try await self.cloud.upload(
                    imageData: jpegData,
                    mimeType: .jpg,
                    progress: nil,
                    for: macId
                )
            }
        }

        if let localBackground = localImages.getCustomBackground(for: macId) {
            try await uploadBackground(localBackground)
            return sensor.any
        }

        do {
            let image = try await propertiesService.getImage(for: sensor)
            try await uploadBackground(image)
        } catch {
            return sensor.any
        }
        return sensor.any
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

    private func checkAndClearGlobalSettings() {
        Task { [weak self] in
            guard let self else { return }
            if let sensors = try? await self.storage.readAll(), sensors.isEmpty {
                self.localSyncState.setSyncDate(nil)
            }
        }
    }
}

private extension RuuviServiceOwnershipImpl {
    func ensureFullMac(for sensor: RuuviTagSensor) async throws -> MACIdentifier {
        guard let macId = sensor.macId else {
            throw RuuviServiceError.macIdIsNil
        }

        let storedFull = localIDs.fullMac(for: macId)
        let dataFormat = RuuviDataFormat.dataFormat(from: sensor.version)
        if dataFormat == .v6,
           macId.value.needsFullMacLookup,
           storedFull == nil {
            let result = try await checkOwner(macId: macId)
            if let sensorString = result.1 {
                return sensorString.lowercased().mac
            } else {
                return macId
            }
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
