import SwiftUI
import UIKit

public class ActivityPresenterStateHolder: ObservableObject {
    @Published var state: ActivityPresenterState = .dismiss
    @Published var position: ActivityPresenterPosition = .bottom
}

public class ActivityPresenterViewProvider: NSObject {
    private var stateHolder: ActivityPresenterStateHolder

    public init(stateHolder: ActivityPresenterStateHolder) {
        self.stateHolder = stateHolder
    }

    public func makeViewController() -> UIViewController {
        UIHostingController(
            rootView: ActivityPresenterView().environmentObject(stateHolder)
        )
    }

    func updateState(_ newState: ActivityPresenterState) {
        stateHolder.state = newState
    }

    func updatePosition(_ position: ActivityPresenterPosition) {
        stateHolder.position = position
    }
}
