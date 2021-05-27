import Foundation
import Future
import RuuviOntology

public protocol RuuviCloud {
    @discardableResult
    func requestCode(email: String) -> Future<String, RuuviCloudError>

    @discardableResult
    func validateCode(code: String) -> Future<String, RuuviCloudError>

    @discardableResult
    func loadSensors() -> Future<[CloudSensor], RuuviCloudError>
}

public protocol RuuviCloudFactory {
    func create(baseUrl: URL, apiKey: String?) -> RuuviCloud
}

extension RuuviCloudFactory {
    public func create(baseUrl: URL) -> RuuviCloud {
        return create(baseUrl: baseUrl, apiKey: nil)
    }
}
