import Foundation

protocol TagChartsInteractorOutput: class {
    var isLoading: Bool { get set }
    func interactorDidError(_ error: RUError)
    func interactorDidUpdate(sensor: AnyRuuviTagSensor)
}
