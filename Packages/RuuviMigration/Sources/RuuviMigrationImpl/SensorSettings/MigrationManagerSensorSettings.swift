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
            ruuviStorage.readAll().on(success: { ruuviTags in
                ruuviTags.forEach { ruuviTag in
                    if let luid = ruuviTag.luid {
                        let pair = self.calibrationPersistence.humidityOffset(for: luid)
                        self.ruuviOffsetCalibrationService.set(
                            offset: pair.0 / 100.0,
                            of: .humidity,
                            for: ruuviTag
                        ).on(success: { _ in
                            self.calibrationPersistence
                                .setHumidity(date: nil, offset: 0.0, for: luid)
                        })
                    }
                }
            })
            didMigrateSensorSettings = true
        }
    }
}
