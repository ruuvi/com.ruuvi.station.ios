import ComposableArchitecture

@Reducer
struct OnboardFeature {
    struct State: Equatable {
        let pages: [OnboardViewModel] = buildOnboardingPages()
        var dashboard = StackState<DashboardFeature.State>()
        @PresentationState var benefits: BenefitsFeature.State?
    }
    enum Action {
        case routeToDashboard(StackAction<DashboardFeature.State, DashboardFeature.Action>)
        case onContinue
        case routeToBenefits(PresentationAction<BenefitsFeature.Action>)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .routeToDashboard:
                return .none
            case .onContinue:
                state.benefits = BenefitsFeature.State()
                return .none
            case .routeToBenefits(.presented(.delegate(.cancel))):
                state.benefits = nil
                return .none
            case .routeToBenefits(.presented(.delegate(.didSkipSignIn))):
                state.benefits = nil
                state.dashboard.append(DashboardFeature.State())
                return .none
            case .routeToBenefits:
                state.benefits = BenefitsFeature.State()
                return .none
            }
        }
        .ifLet(\.$benefits, action: \.routeToBenefits) {
            BenefitsFeature()
        }
        .forEach(\.dashboard, action: \.routeToDashboard) {
            DashboardFeature()
        }
    }
}
