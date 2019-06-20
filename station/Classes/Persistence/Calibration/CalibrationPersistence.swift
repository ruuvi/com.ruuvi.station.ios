import Foundation

protocol CalibrationPersistence {
    func humidityOffset(for uuid: String) -> (Double,Date?)
    func setHumidity(date: Date?, offset: Double, for uuid: String)
}
