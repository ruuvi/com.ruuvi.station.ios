import Foundation
import RuuviOntology

protocol CalibrationPersistence {
    func humidityOffset(for identifier: Identifier) -> (Double, Date?)
    func setHumidity(date: Date?, offset: Double, for identifier: Identifier)
}
