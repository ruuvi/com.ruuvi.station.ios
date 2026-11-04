#if SWIFT_PACKAGE
    import RuuviMigration
#endif
import Foundation
import RuuviOntology
import RuuviService
import RuuviStorage

final class MigrationManagerSensorSettings: RuuviMigration {
    private let calibrationPersistence: CalibrationPersistence
    private let ruuviStorage: RuuviStorage
    private let ruuviOffsetCalibrationService: RuuviServiceOffsetCalibration
    @MainActor private var isRunning = false

    init(
        calibrationPersistence: CalibrationPersistence,
        ruuviStorage: RuuviStorage,
        ruuviOffsetCalibrationService: RuuviServiceOffsetCalibration,
        defaults: UserDefaults = .standard
    ) {
        self.calibrationPersistence = calibrationPersistence
        self.ruuviStorage = ruuviStorage
        self.ruuviOffsetCalibrationService = ruuviOffsetCalibrationService
        _didMigrateSensorSettings = UserDefault(
            "MigrationManagerSensorSettings.didMigrateSensorSettings", defaultValue: false, defaults: defaults)
    }

    @UserDefault("MigrationManagerSensorSettings.didMigrateSensorSettings", defaultValue: false)
    private var didMigrateSensorSettings: Bool

    func migrateIfNeeded() {
        Task { @MainActor [self] in try? await migrate() }
    }

    /// Keep the legacy values until every write succeeds, allowing an interrupted migration to retry.
    @MainActor func migrate() async throws {
        guard !didMigrateSensorSettings, !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        let sensors = try await ruuviStorage.readAll()
        var migrated = [LocalIdentifier]()
        for sensor in sensors {
            try Task.checkCancellation()
            guard let luid = sensor.luid else { continue }
            let (offset, date) = calibrationPersistence.humidityOffset(for: luid)
            guard offset != 0 || date != nil else { continue }
            _ = try await ruuviOffsetCalibrationService.set(offset: offset / 100, of: .humidity, for: sensor)
            migrated.append(luid)
        }
        try Task.checkCancellation()
        for luid in migrated { calibrationPersistence.setHumidity(date: nil, offset: 0, for: luid) }
        didMigrateSensorSettings = true
    }
}
