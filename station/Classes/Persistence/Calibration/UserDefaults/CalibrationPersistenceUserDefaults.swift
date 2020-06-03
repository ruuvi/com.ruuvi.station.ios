import Foundation

class CalibrationPersistenceUserDefaults: CalibrationPersistence {

    private let humidityOffsetDatePrefixUDKey =
    "CalibrationPersistenceUserDefaults.humidityOffsetDate"
    private let humidityOffsetPrefixUDKey =
    "CalibrationPersistenceUserDefaults.humidityOffset"

    func humidityOffset(for luid: LocalIdentifier) -> (Double, Date?) {
        let uuid = luid.value
        let date = UserDefaults.standard.object(forKey: humidityOffsetDatePrefixUDKey + uuid) as? Date
        let offset = UserDefaults.standard.double(forKey: humidityOffsetPrefixUDKey + uuid)
        return (offset, date)
    }

    func setHumidity(date: Date?, offset: Double, for luid: LocalIdentifier) {
        let uuid = luid.value
        UserDefaults.standard.set(date, forKey: humidityOffsetDatePrefixUDKey + uuid)
        UserDefaults.standard.set(offset, forKey: humidityOffsetPrefixUDKey + uuid)
    }

}
