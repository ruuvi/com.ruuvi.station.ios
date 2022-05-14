import SwiftUI

struct UnauthorizedView: View {
    var body: some View {
        VStack {
            Text("Sign in to use the widget.")
                .font(.custom(Constants.muliBold.rawValue,
                              size: 16,
                              relativeTo: .headline))
                .minimumScaleFactor(0.5)
        }.padding()
    }
}
