import Foundation

protocol TagChartsInteractorOutput: class {
    func interactorDidError(_ error: RUError)
    func interactorDidDeleteTag()
    func interactorDidDeleteLast()
    var isLoading: Bool { get set }
}
