import Foundation
import RuuviStorage
import RuuviService

class MigrationManagerSensorSettings: MigrationManager {
    var calibrationPersistence: CalibrationPersistence!
    var errorPresenter: ErrorPresenter!
    var ruuviStorage: RuuviStorage!
    var ruuviOffsetCalibrationService: RuuviServiceOffsetCalibration!

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
            }, failure: {[weak self] error in
                self?.errorPresenter.present(error: error)
            })
            didMigrateSensorSettings = true
        }
    }
}
