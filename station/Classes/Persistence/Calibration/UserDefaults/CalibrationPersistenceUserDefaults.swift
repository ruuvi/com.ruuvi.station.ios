import Foundation

class CalibrationPersistenceUserDefaults: CalibrationPersistence {

    func humidityOffset(for uuid: String) -> (Double, Date?) {
        let date = UserDefaults.standard.object(forKey: "CalibrationPersistenceUserDefaults.humidityOffsetDate" + uuid) as? Date
        let offset = UserDefaults.standard.double(forKey: "CalibrationPersistenceUserDefaults.humidityOffset" + uuid)
        return (offset, date)
    }

    func setHumidity(date: Date?, offset: Double, for uuid: String) {
        UserDefaults.standard.set(date, forKey: "CalibrationPersistenceUserDefaults.humidityOffsetDate" + uuid)
        UserDefaults.standard.set(offset, forKey: "CalibrationPersistenceUserDefaults.humidityOffset" + uuid)
    }

}
