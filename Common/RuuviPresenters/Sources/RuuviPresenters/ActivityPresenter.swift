import Foundation

public protocol ActivityPresenter {
    func show(
        with state: ActivityPresenterState,
        atPosition position: ActivityPresenterPosition
    )
    func update(with state: ActivityPresenterState)
    func dismiss(immediately: Bool)
}

public extension ActivityPresenter {
    func show(
        with state: ActivityPresenterState,
        atPosition position: ActivityPresenterPosition = .bottom
    ) {
        show(with: state, atPosition: position)
    }

    func dismiss(immediately: Bool = false) {
        dismiss(immediately: immediately)
    }
}
