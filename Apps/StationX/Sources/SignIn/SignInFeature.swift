import ComposableArchitecture

@Reducer
struct SignInFeature {
    struct State: Equatable {
    }
    enum Action {
        enum Delegate {
            case closeSignIn
        }
        case requestCode
        case delegate(Delegate)
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .delegate:
                return .none
            case .requestCode:
                return .none
            }
        }
    }
}
