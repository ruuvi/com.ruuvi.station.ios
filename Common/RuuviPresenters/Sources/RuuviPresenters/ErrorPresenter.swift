import Foundation

public protocol ErrorPresenter {
    func present(error: Error)
}
