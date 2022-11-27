import SwiftUI

struct UnauthorizedView: View {
    var body: some View {
        ZStack {
            Color.backgroundColor.edgesIgnoringSafeArea(.all)
        }
        VStack {
            Text("Widgets.Unauthorized.message".localized)
                .font(.custom(Constants.muliBold.rawValue,
                              size: 16,
                              relativeTo: .headline))
                .minimumScaleFactor(0.5)
        }.padding()
    }
}
