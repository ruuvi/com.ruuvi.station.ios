import Foundation
import Future
import RuuviOntology

public protocol RuuviCloud {
    @discardableResult
    func requestCode(email: String) -> Future<String, RuuviCloudError>

    @discardableResult
    func validateCode(code: String) -> Future<String, RuuviCloudError>

    @discardableResult
    func loadSensors() -> Future<[AnyCloudSensor], RuuviCloudError>

    @discardableResult
    func loadRecords(
        macId: MACIdentifier,
        since: Date,
        until: Date?
    ) -> Future<[AnyRuuviTagSensorRecord], RuuviCloudError>

    @discardableResult
    func claim(macId: MACIdentifier) -> Future<MACIdentifier, RuuviCloudError>

    @discardableResult
    func unclaim(macId: MACIdentifier) -> Future<MACIdentifier, RuuviCloudError>

    @discardableResult
    func share(
        macId: MACIdentifier,
        with email: String
    ) -> Future<MACIdentifier, RuuviCloudError>

    @discardableResult
    func unshare(
        macId: MACIdentifier,
        with email: String?
    ) -> Future<MACIdentifier, RuuviCloudError>

    @discardableResult
    func loadShared() -> Future<Set<AnyShareableSensor>, RuuviCloudError>

    func update(
        name: String,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensor, RuuviCloudError>
}

public protocol RuuviCloudFactory {
    func create(baseUrl: URL, apiKey: String?) -> RuuviCloud
}

extension RuuviCloudFactory {
    public func create(baseUrl: URL) -> RuuviCloud {
        return create(baseUrl: baseUrl, apiKey: nil)
    }
}
