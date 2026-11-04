#if SWIFT_PACKAGE
    import RuuviMigration
#endif
#if SWIFT_PACKAGE
    import RuuviOntology
    import RuuviLocal
    import RuuviPool
    import RuuviContext
    import RuuviStorage
    import RuuviService
#endif
import Foundation

extension UserDefaults {
    func optionalDouble(forKey defaultName: String) -> Double? {
        let defaults = self
        if let value = defaults.object(forKey: defaultName) {
            return value as? Double
        }
        return nil
    }

}
