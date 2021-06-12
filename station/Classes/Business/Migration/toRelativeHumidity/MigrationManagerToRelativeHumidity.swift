import Foundation
import RuuviService
import RuuviStorage
import RuuviOntology

final class MigrationManagerToRelativeHumidity: MigrationManager {
    var alertService: RuuviServiceAlert!
    var ruuviStorage: RuuviStorage!

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedUdKey) else { return }
        // disable dew point and absolute humidity alerts
        self.ruuviStorage.readAll()
            .on(success: { sensors in
                sensors.forEach({ sensor in
                    self.alertService.unregister(
                        type: .dewPoint(lower: 0, upper: 0),
                        ruuviTag: sensor
                    )
                    self.alertService.unregister(
                        type: .humidity(
                            lower: Humidity.zeroAbsolute,
                            upper: Humidity.zeroAbsolute
                        ),
                        ruuviTag: sensor
                    )
                })
            })
        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }

    private let migratedUdKey = "MigrationManagerToRelativeHumidity.migrated"
}
