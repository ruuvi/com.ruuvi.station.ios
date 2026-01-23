import Foundation
import RuuviContext
import RuuviLocal
import RuuviPool
import RuuviService
import RuuviStorage
import UIKit

final class RuuviMigrationFixRHAlerts: RuuviMigration {
    private let ruuviStorage: RuuviStorage
    private let ruuviAlertService: RuuviServiceAlert
    private let migratedUdKey = "RuuviMigrationFixRHAlerts.migrated"

    init(
        ruuviStorage: RuuviStorage,
        ruuviAlertService: RuuviServiceAlert
    ) {
        self.ruuviStorage = ruuviStorage
        self.ruuviAlertService = ruuviAlertService
    }

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedUdKey) else { return }
        Task { [weak self] in
            guard let self else { return }
            let sensors = try? await ruuviStorage.readAll()
            sensors?.forEach { sensor in
                if let lower = ruuviAlertService.lowerRelativeHumidity(for: sensor),
                   lower > 1.0 {
                    ruuviAlertService.setLower(
                        relativeHumidity: lower / 100.0,
                        ruuviTag: sensor
                    )
                }
                if let upper = ruuviAlertService.upperRelativeHumidity(for: sensor), upper > 1.0 {
                    ruuviAlertService.setUpper(
                        relativeHumidity: upper / 100.0,
                        ruuviTag: sensor
                    )
                }
            }
        }
        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }
}
