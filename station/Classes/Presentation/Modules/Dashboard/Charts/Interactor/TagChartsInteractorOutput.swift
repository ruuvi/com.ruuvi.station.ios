import Foundation

protocol TagChartsInteractorOutput: AnyObject {
    var isLoading: Bool { get set }
    func interactorDidError(_ error: RUError)
    func interactorDidUpdate(sensor: AnyRuuviTagSensor)
    func interactorDidSyncComplete(_ recordsCount: Int)
}
