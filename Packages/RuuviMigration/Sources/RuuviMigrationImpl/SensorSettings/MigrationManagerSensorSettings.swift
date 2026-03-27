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
            Task {
                if let ruuviTags = try? await self.ruuviStorage.readAll() {
                    ruuviTags.forEach { ruuviTag in
                        if let luid = ruuviTag.luid {
                            let pair = self.calibrationPersistence.humidityOffset(for: luid)
                            Task { [weak self] in
                                guard let self else { return }
                                do {
                                    _ = try await self.ruuviOffsetCalibrationService.set(
                                        offset: pair.0 / 100.0,
                                        of: .humidity,
                                        for: ruuviTag
                                    )
                                    self.calibrationPersistence
                                        .setHumidity(date: nil, offset: 0.0, for: luid)
                                } catch {
                                    return
                                }
                            }
                        }
                    }
                }
            }
            didMigrateSensorSettings = true
        }
    }
}
