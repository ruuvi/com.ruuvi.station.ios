#if SWIFT_PACKAGE
    import RuuviStorage
    import RuuviCloud
    import RuuviPool
    import RuuviRepository
    import RuuviCore
#endif
import Foundation
import RuuviLocal
import RuuviOntology

public protocol RuuviServiceExport {
    func csvLog(
        for uuid: String,
        version: Int,
        settings: SensorSettings?
    ) async throws(RuuviServiceError) -> URL
    func xlsxLog(
        for uuid: String,
        version: Int,
        settings: SensorSettings?
    ) async throws(RuuviServiceError) -> URL
}
