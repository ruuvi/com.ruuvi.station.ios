import SwiftUI
import Localize_Swift

struct UnauthorizedView: View {
    var body: some View {
        VStack {
            Text("Widgets.Unauthorized.message".localized())
                .font(.custom(Constants.muliBold.rawValue,
                              size: 16,
                              relativeTo: .headline))
                .minimumScaleFactor(0.5)
        }.padding()
    }
}
