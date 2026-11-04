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

protocol CalibrationPersistence {
    func humidityOffset(for identifier: Identifier) -> (Double, Date?)
    func setHumidity(date: Date?, offset: Double, for identifier: Identifier)
}
