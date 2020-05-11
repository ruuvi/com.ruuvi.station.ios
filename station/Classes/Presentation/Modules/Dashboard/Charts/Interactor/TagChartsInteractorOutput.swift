import Foundation

protocol TagChartsInteractorOutput: class {
    func interactorDidError(_ error: RUError)
    func interactorDidDeleteTag()
}
