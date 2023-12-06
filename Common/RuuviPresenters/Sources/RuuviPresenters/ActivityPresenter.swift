import Foundation

public protocol ActivityPresenter {
    func setPosition(_ position: ActivityPresenterPosition)
    func show(with state: ActivityPresenterState)
    func update(with state: ActivityPresenterState)
    func dismiss(immediately: Bool)
}

public extension ActivityPresenter {
    func dismiss(immediately: Bool = false) {
        dismiss(immediately: immediately)
    }
}
