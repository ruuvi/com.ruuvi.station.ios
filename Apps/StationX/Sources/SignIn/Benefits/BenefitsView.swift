import ComposableArchitecture
import RuuviLocalization
import SwiftUI

struct BenefitsView: View {
    let store: StoreOf<BenefitsFeature>

    var body: some View {
        NavigationStackStore(self.store.scope(state: \.signIn, action: \.routeToSignIn)) {
            VStack {
                Text(RuuviLocalization.whyShouldSignIn)
                    .padding()
                NavigationLink(state: SignInFeature.State()) {
                    Text(RuuviLocalization.onboardingContinue)
                }
            }
        } destination: { store in
            SignInView(store: store)
        }
    }
}
