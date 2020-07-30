import Foundation

protocol TagChartsInteractorOutput: class {
    func interactorDidError(_ error: RUError)
    var isLoading: Bool { get set }
}
