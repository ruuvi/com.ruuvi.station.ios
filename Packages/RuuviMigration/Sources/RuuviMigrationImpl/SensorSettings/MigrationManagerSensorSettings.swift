import Foundation
import RuuviService
import RuuviStorage

class MigrationManagerSensorSettings: RuuviMigration {
    private let calibrationPersistence: CalibrationPersistence
    private let ruuviStorage: RuuviStorage
    private let ruuviOffsetCalibrationService: RuuviServiceOffsetCalibration

    init(
        calibrationPersistence: CalibrationPersistence,
        ruuviStorage: RuuviStorage,
        ruuviOffsetCalibrationService: RuuviServiceOffsetCalibration
    ) {
        self.calibrationPersistence = calibrationPersistence
        self.ruuviStorage = ruuviStorage
        self.ruuviOffsetCalibrationService = ruuviOffsetCalibrationService
    }

    @UserDefault("MigrationManagerSensorSettings.didMigrateSensorSettings", defaultValue: false)
    private var didMigrateSensorSettings: Bool

    func migrateIfNeeded() {
        if !didMigrateSensorSettings {
            Task { [weak self] in
                guard let self else { return }
                do {
                    let ruuviTags = try await ruuviStorage.readAll()
                    for ruuviTag in ruuviTags {
                        guard let luid = ruuviTag.luid else { continue }
                        let pair = calibrationPersistence.humidityOffset(for: luid)
                        do {
                            _ = try await ruuviOffsetCalibrationService.set(
                                offset: pair.0 / 100.0,
                                of: .humidity,
                                for: ruuviTag
                            )
                            calibrationPersistence.setHumidity(date: nil, offset: 0.0, for: luid)
                        } catch {
                            // Continue with next sensor even if one fails
                        }
                    }
                } catch {
                    // Ignore migration failure; will not set flag if readAll fails
                }
            }
            didMigrateSensorSettings = true
        }
    }
}
