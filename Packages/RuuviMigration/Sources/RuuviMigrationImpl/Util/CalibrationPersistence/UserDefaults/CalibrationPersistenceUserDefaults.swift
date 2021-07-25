import Foundation
import RuuviOntology

class CalibrationPersistenceUserDefaults: CalibrationPersistence {

    private let humidityOffsetDatePrefixUDKey =
    "CalibrationPersistenceUserDefaults.humidityOffsetDate"
    private let humidityOffsetPrefixUDKey =
    "CalibrationPersistenceUserDefaults.humidityOffset"

    func humidityOffset(for identifier: Identifier) -> (Double, Date?) {
        let uuid = identifier.value
        let date = UserDefaults.standard.object(forKey: humidityOffsetDatePrefixUDKey + uuid) as? Date
        let offset = UserDefaults.standard.double(forKey: humidityOffsetPrefixUDKey + uuid)
        return (offset, date)
    }

    func setHumidity(date: Date?, offset: Double, for identifier: Identifier) {
        UserDefaults.standard.set(date, forKey: humidityOffsetDatePrefixUDKey + identifier.value)
        UserDefaults.standard.set(offset, forKey: humidityOffsetPrefixUDKey + identifier.value)
    }
}
