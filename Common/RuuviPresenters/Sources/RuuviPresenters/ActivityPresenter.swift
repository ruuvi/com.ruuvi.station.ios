import Foundation

public protocol ActivityPresenter {
    func increment()
    func increment(with message: String)
    func decrement()
}
