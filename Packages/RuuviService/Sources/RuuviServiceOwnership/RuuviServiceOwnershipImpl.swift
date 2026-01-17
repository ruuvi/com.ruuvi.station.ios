// swiftlint:disable file_length

import Foundation
import UIKit
import Future
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
    public func loadShared(for sensor: RuuviTagSensor) -> Future<Set<AnyShareableSensor>, RuuviServiceError> {
        let promise = Promise<Set<AnyShareableSensor>, RuuviServiceError>()
        cloud.loadShared(for: sensor)
            .on(success: { shareableSensors in
                promise.succeed(value: shareableSensors)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func share(
        macId: MACIdentifier,
        with email: String
    ) -> Future<ShareSensorResponse, RuuviServiceError> {
        let promise = Promise<ShareSensorResponse, RuuviServiceError>()
        cloud.share(macId: macId, with: email)
            .on(success: { result in
                promise.succeed(value: result)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func unshare(macId: MACIdentifier, with email: String?) -> Future<MACIdentifier, RuuviServiceError> {
        let promise = Promise<MACIdentifier, RuuviServiceError>()
        cloud.unshare(macId: macId, with: email)
            .on(success: { macId in
                promise.succeed(value: macId)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func claim(sensor: RuuviTagSensor) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        guard let macId = sensor.macId
        else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }
        guard let owner = ruuviUser.email
        else {
            promise.fail(error: .ruuviCloud(.notAuthorized))
            return promise.future
        }
        ensureFullMac(for: sensor)
            .on(success: { [weak self] canonicalMac in
                guard let self else { return }
                self.cloud.claim(name: sensor.name, macId: canonicalMac)
                    .on(success: { [weak self] _ in
                        guard let self else { return }
                        self.handleSensorClaimed(
                            sensor: sensor,
                            owner: owner,
                            macId: macId,
                            promise: promise
                        )
                    }, failure: { error in
                        promise.fail(error: .ruuviCloud(error))
                    })
            }, failure: { error in
                promise.fail(error: error)
            })
        return promise.future
    }

    @discardableResult
    public func contest(
        sensor: RuuviTagSensor,
        secret: String
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        guard let macId = sensor.macId
        else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }

        guard let owner = ruuviUser.email
        else {
            promise.fail(error: .ruuviCloud(.notAuthorized))
            return promise.future
        }

        ensureFullMac(for: sensor)
            .on(success: { [weak self] canonicalMac in
                guard let self else { return }
                self.cloud.contest(macId: canonicalMac, secret: secret)
                    .on(success: { [weak self] _ in
                        guard let self else { return }
                        self.handleSensorClaimed(
                            sensor: sensor,
                            owner: owner,
                            macId: macId,
                            promise: promise
                        )
                    }, failure: { error in
                        promise.fail(error: .ruuviCloud(error))
                    })
            }, failure: { error in
                promise.fail(error: error)
            })
        return promise.future
    }

    @discardableResult
    public func unclaim(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        ensureFullMac(for: sensor)
            .on(success: { [weak self] canonicalMac in
                guard let self else { return }
                self.cloud.unclaim(
                    macId: canonicalMac,
                    removeCloudHistory: removeCloudHistory
                )
                .on(success: { [weak self] _ in
                    guard let self else { return }
                    let unclaimedSensor = sensor
                        .with(isClaimed: false)
                        .with(canShare: false)
                        .with(sharedTo: [])
                        .with(isCloudSensor: false)
                        .withoutOwner()
                    self.pool
                        .update(unclaimedSensor)
                        .on(success: { _ in
                            promise.succeed(value: unclaimedSensor.any)
                        }, failure: { error in
                            promise.fail(error: .ruuviPool(error))
                        })
                }, failure: { error in
                    promise.fail(error: .ruuviCloud(error))
                })
            }, failure: { error in
                promise.fail(error: error)
            })
        return promise.future
    }

    @discardableResult
    public func add(
        sensor: RuuviTagSensor,
        record: RuuviTagSensorRecord
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        let entity = pool.create(sensor)
        let recordEntity = pool.create(record)
        let recordLast = pool.createLast(record)
        Future.zip(entity, recordEntity, recordLast).on(success: { _ in
            promise.succeed(value: sensor.any)
        }, failure: { error in
            promise.fail(error: .ruuviPool(error))
        })
        return promise.future
    }

    @discardableResult
    public func remove(
        sensor: RuuviTagSensor,
        removeCloudHistory: Bool
    ) -> Future<AnyRuuviTagSensor, RuuviServiceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviServiceError>()
        let deleteTagOperation = pool.delete(sensor)
        let deleteRecordsOperation = pool.deleteAllRecords(sensor.id)
        let deleteLastRecordOperation = pool.deleteLast(sensor.id)
        let deleteSensorSettingsOperation = pool.deleteSensorSettings(sensor)
        var unshareOperation: Future<MACIdentifier, RuuviServiceError>?
        var unclaimOperation: Future<AnyRuuviTagSensor, RuuviServiceError>?

        if let macId = sensor.macId,
           sensor.isCloud {
            if sensor.isOwner {
                unclaimOperation = unclaim(
                    sensor: sensor,
                    removeCloudHistory: removeCloudHistory
                )
            } else {
                unshareOperation = unshare(macId: macId, with: nil)
            }
        }

        // Remove custom image
        propertiesService.removeImage(for: sensor)

        // Clean up all sensor-related local prefs data
        cleanupSensorData(for: sensor)

        Future.zip([
            deleteTagOperation,
            deleteRecordsOperation,
            deleteLastRecordOperation,
            deleteSensorSettingsOperation,
        ])
        .on(success: { [weak self] _ in
            // Check if we should clear global settings after deletion
            self?.checkAndClearGlobalSettings()

            if let unclaimOperation {
                unclaimOperation.on()
                promise.succeed(value: sensor.any)
            } else if let unshareOperation {
                unshareOperation.on()
                promise.succeed(value: sensor.any)
            } else {
                promise.succeed(value: sensor.any)
            }
        }, failure: { error in
            promise.fail(error: .ruuviPool(error))
        })

        return promise.future
    }

    @discardableResult
    public func checkOwner(macId: MACIdentifier) -> Future<(String?, String?), RuuviServiceError> {
        let promise = Promise<(String?, String?), RuuviServiceError>()
        cloud.checkOwner(macId: macId)
            .on(success: { [weak self] result in
                if let self,
                   let sensorString = result.1 {
                    let fullMac = sensorString.lowercased().mac
                    let original = self.localIDs.originalMac(for: fullMac) ?? macId
                    self.localIDs.set(fullMac: fullMac, for: original)
                }
                promise.succeed(value: result)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        return promise.future
    }

    @discardableResult
    public func updateShareable(for sensor: RuuviTagSensor) -> Future<Bool, RuuviServiceError> {
        let promise = Promise<Bool, RuuviServiceError>()
        pool.update(sensor).on(success: { _ in
            promise.succeed(value: true)
        }, failure: { error in
            promise.fail(error: .ruuviPool(error))
        })
        return promise.future
    }
}

extension RuuviServiceOwnershipImpl {
    private func handleSensorClaimed(
        sensor: RuuviTagSensor,
        owner: String,
        macId: MACIdentifier,
        promise: Promise<AnyRuuviTagSensor, RuuviServiceError>
    ) {
        let claimedSensor = sensor
            .with(owner: owner)
            .with(isClaimed: true)
            .with(isCloudSensor: true)
            .with(isOwner: true)
        pool
            .update(claimedSensor)
            .on(success: { [weak self] _ in
                self?.handleUpdatedSensor(
                    sensor: claimedSensor,
                    promise: promise,
                    macId: macId
                )
            }, failure: { error in
                promise.fail(error: .ruuviPool(error))
            })
    }

    private func handleUpdatedSensor(
        sensor: RuuviTagSensor,
        promise: Promise<AnyRuuviTagSensor, RuuviServiceError>,
        macId: MACIdentifier
    ) {
        storage.readSensorSettings(sensor).on { [weak self] settings in
            guard let self else { return }
            self.cloud.update(
                temperatureOffset: settings?.temperatureOffset ?? 0,
                humidityOffset: (settings?.humidityOffset ?? 0) * 100, // fraction local, % on cloud
                pressureOffset: (settings?.pressureOffset ?? 0) * 100, // hPa local, Pa on cloud
                for: sensor
            ).on()
        }

        AlertType.allCases.forEach { type in
            if let alert = alertService.alert(for: sensor, of: type) {
                alertService.register(type: alert, ruuviTag: sensor)
            }
        }

        func uploadBackground(_ image: UIImage) {
            guard let jpegData = image.jpegData(compressionQuality: 1.0) else {
                promise.fail(error: .failedToGetJpegRepresentation)
                return
            }
            let remote = self.cloud.upload(
                imageData: jpegData,
                mimeType: .jpg,
                progress: nil,
                for: macId
            )
            remote.on(success: { _ in
                promise.succeed(value: sensor.any)
            }, failure: { error in
                promise.fail(error: .ruuviCloud(error))
            })
        }

        if let localBackground = localImages.getCustomBackground(for: macId) {
            uploadBackground(localBackground)
            return
        }

        propertiesService.getImage(for: sensor).on(success: { image in
            uploadBackground(image)
        }, failure: { _ in
            promise.succeed(value: sensor.any)
        })
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

    private func checkAndClearGlobalSettings() {
        storage.readAll()
            .on(success: { [weak self] sensors in
                if sensors.isEmpty {
                    self?.localSyncState.setSyncDate(nil)
                }
            })
    }
}

private extension RuuviServiceOwnershipImpl {
    func ensureFullMac(for sensor: RuuviTagSensor) -> Future<MACIdentifier, RuuviServiceError> {
        let promise = Promise<MACIdentifier, RuuviServiceError>()
        guard let macId = sensor.macId else {
            promise.fail(error: .macIdIsNil)
            return promise.future
        }

        let storedFull = localIDs.fullMac(for: macId)
        let dataFormat = RuuviDataFormat.dataFormat(from: sensor.version)
        if dataFormat == .v6,
           macId.value.needsFullMacLookup,
           storedFull == nil {
            checkOwner(macId: macId)
                .on(success: { [weak self] result in
                    guard let self else { return }
                    if let sensorString = result.1 {
                        let fullMac = sensorString.lowercased().mac
                        let original = self.localIDs.originalMac(for: fullMac) ?? macId
                        self.localIDs.set(fullMac: fullMac, for: original)
                        promise.succeed(value: fullMac)
                    } else {
                        promise.succeed(value: macId)
                    }
                }, failure: { error in
                    promise.fail(error: error)
                })
        } else {
            promise.succeed(value: storedFull ?? macId)
        }

        return promise.future
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
