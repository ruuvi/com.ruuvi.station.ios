import Foundation

protocol CalibrationPersistence {
    func humidityOffset(for identifier: Identifier) -> (Double, Date?)
    func setHumidity(date: Date?, offset: Double, for identifier: Identifier)
}
