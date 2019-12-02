import Foundation

class CalibrationPersistenceUserDefaults: CalibrationPersistence {

    private let humidityOffsetDatePrefixUDKey =
    "CalibrationPersistenceUserDefaults.humidityOffsetDate"
    private let humidityOffsetPrefixUDKey =
    "CalibrationPersistenceUserDefaults.humidityOffset"

    func humidityOffset(for uuid: String) -> (Double, Date?) {
        let date = UserDefaults.standard.object(forKey: humidityOffsetDatePrefixUDKey + uuid) as? Date
        let offset = UserDefaults.standard.double(forKey: humidityOffsetPrefixUDKey + uuid)
        return (offset, date)
    }

    func setHumidity(date: Date?, offset: Double, for uuid: String) {
        UserDefaults.standard.set(date, forKey: humidityOffsetDatePrefixUDKey + uuid)
        UserDefaults.standard.set(offset, forKey: humidityOffsetPrefixUDKey + uuid)
    }

}
