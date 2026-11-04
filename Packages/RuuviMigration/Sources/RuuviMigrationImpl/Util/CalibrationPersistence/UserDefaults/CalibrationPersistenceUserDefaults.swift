#if SWIFT_PACKAGE
    import RuuviMigration
#endif
#if SWIFT_PACKAGE
    import RuuviLocal
    import RuuviPool
    import RuuviContext
    import RuuviStorage
    import RuuviService
#endif
import Foundation
import RuuviOntology

class CalibrationPersistenceUserDefaults: CalibrationPersistence {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private let humidityOffsetDatePrefixUDKey =
        "CalibrationPersistenceUserDefaults.humidityOffsetDate"
    private let humidityOffsetPrefixUDKey =
        "CalibrationPersistenceUserDefaults.humidityOffset"

    func humidityOffset(for identifier: Identifier) -> (Double, Date?) {
        let uuid = identifier.value
        let date = defaults.object(forKey: humidityOffsetDatePrefixUDKey + uuid) as? Date
        let offset = defaults.double(forKey: humidityOffsetPrefixUDKey + uuid)
        return (offset, date)
    }

    func setHumidity(date: Date?, offset: Double, for identifier: Identifier) {
        defaults.set(date, forKey: humidityOffsetDatePrefixUDKey + identifier.value)
        defaults.set(offset, forKey: humidityOffsetPrefixUDKey + identifier.value)
    }
}
