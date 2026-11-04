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

public protocol RuuviServiceCloudSync {
    @discardableResult
    func syncAll() async throws(RuuviServiceError) -> Set<AnyRuuviTagSensor>

    @discardableResult
    func sync(sensor: RuuviTagSensor) async throws(RuuviServiceError) -> [AnyRuuviTagSensorRecord]

    @discardableResult
    func syncAllHistory() async throws(RuuviServiceError) -> Bool

    @discardableResult
    func refreshLatestRecord() async throws(RuuviServiceError) -> Bool

    @discardableResult
    func syncAllRecords() async throws(RuuviServiceError) -> Bool

    @discardableResult
    func syncSettings() async throws(RuuviServiceError) -> RuuviCloudSettings

    @discardableResult
    func executePendingRequests() async throws(RuuviServiceError) -> Bool
}
