import ComposableArchitecture
import RuuviLocalization
import SwiftUI

struct SignInView: View {
    let store: StoreOf<SignInFeature>
    @State private var email: String = ""

    var body: some View {
        Text(RuuviLocalization.signInOrCreateFreeAccount)
        Text(RuuviLocalization.toUseAllAppFeatures)
        TextField(RuuviLocalization.typeYourEmail, text: $email)
        Button {
            store.send(.requestCode)
        } label: {
            Text(RuuviLocalization.requestCode)
        }
        Text(RuuviLocalization.noPasswordNeeded)
        Spacer()
        Button {
            store.send(.delegate(.closeSignIn))
        } label: {
            Text(RuuviLocalization.useWithoutAccount)
        }
    }
}
