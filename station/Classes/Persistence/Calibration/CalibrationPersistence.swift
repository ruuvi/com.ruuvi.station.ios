import Foundation

protocol CalibrationPersistence {
    func humidityOffset(for luid: LocalIdentifier) -> (Double, Date?)
    func setHumidity(date: Date?, offset: Double, for luid: LocalIdentifier)
}
