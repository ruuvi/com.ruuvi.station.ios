#if SWIFT_PACKAGE
    import RuuviStorage
    import RuuviCloud
    import RuuviPool
    import RuuviLocal
    import RuuviRepository
    import RuuviCore
#endif
import Foundation
import RuuviOntology

public protocol RuuviServiceSensorRecords {
    @discardableResult
    func clear(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> Void
}
