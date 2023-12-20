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
    private let queue = DispatchQueue(label: "RuuviMigrationFixRHAlerts", qos: .utility)
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
        queue.async {
            self.ruuviStorage.readAll()
                .on(success: { sensors in
                    sensors.forEach { sensor in
                        if let lower = self.ruuviAlertService.lowerRelativeHumidity(for: sensor),
                           lower > 1.0 {
                            self.ruuviAlertService.setLower(
                                relativeHumidity: lower / 100.0,
                                ruuviTag: sensor
                            )
                        }
                        if let upper = self.ruuviAlertService.upperRelativeHumidity(for: sensor), upper > 1.0 {
                            self.ruuviAlertService.setUpper(
                                relativeHumidity: upper / 100.0,
                                ruuviTag: sensor
                            )
                        }
                    }
                })
        }
        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }
}
