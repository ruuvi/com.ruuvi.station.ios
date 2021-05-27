import Foundation
import Future
import RuuviOntology

public protocol RuuviCloud {
    @discardableResult
    func load() -> Future<[AnyRuuviTagSensor], RuuviCloudError>
}

public protocol RuuviCloudFactory {
    func create() -> RuuviCloud
}
