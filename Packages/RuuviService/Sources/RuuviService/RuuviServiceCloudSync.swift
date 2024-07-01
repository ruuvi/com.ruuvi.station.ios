import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceCloudSync {
    @discardableResult
    func syncAll() -> Future<Set<AnyRuuviTagSensor>, RuuviServiceError>

    @discardableResult
    func sync(sensor: RuuviTagSensor) -> Future<[AnyRuuviTagSensorRecord], RuuviServiceError>

    @discardableResult
    func syncAllHistory() -> Future<Bool, RuuviServiceError>

    @discardableResult
    func refreshLatestRecord() -> Future<Bool, RuuviServiceError>

    @discardableResult
    func syncAllRecords() -> Future<Bool, RuuviServiceError>

    @discardableResult
    func syncSettings() -> Future<RuuviCloudSettings, RuuviServiceError>

    @discardableResult
    func executePendingRequests() -> Future<Bool, RuuviServiceError>
}
