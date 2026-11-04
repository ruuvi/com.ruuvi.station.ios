#if SWIFT_PACKAGE
    import RuuviMigration
#endif
#if SWIFT_PACKAGE
    import RuuviOntology
#endif
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
            Task { @MainActor [self] in
                do throws(RuuviStorageError) {
                    let value = try await self.ruuviStorage.readAll()
                    ({ sensors in
                        sensors.forEach { sensor in
                            if let lower = self.ruuviAlertService.lowerRelativeHumidity(for: sensor),
                                lower > 1.0
                            {
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
                    })(value)
                } catch {
                }
            }
        }
        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }
}
