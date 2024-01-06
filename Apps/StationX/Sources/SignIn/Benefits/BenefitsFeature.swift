import ComposableArchitecture

@Reducer
struct BenefitsFeature {
    struct State: Equatable {
        var signIn = StackState<SignInFeature.State>()
    }

    enum Action {
        enum Delegate {
            case cancel
            case didSkipSignIn
        }
        case delegate(Delegate)
        case routeToSignIn(StackAction<SignInFeature.State, SignInFeature.Action>)
    }

    var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .delegate:
                return .none
            case .routeToSignIn(.element(_, action: .delegate(.closeSignIn))):
                return .run { send in
                    await send(.delegate(.didSkipSignIn))
                }
            case .routeToSignIn:
                return .none
            }
        }
        .forEach(\.signIn, action: \.routeToSignIn) {
            SignInFeature()
        }
    }
}
