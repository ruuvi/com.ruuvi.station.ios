import SwiftUI

struct EmptyWidgetView: View {
    var entry: WidgetProvider.Entry
    var body: some View {
        VStack {
            Text(entry.config.ruuviWidgetTag == nil ? "Force tap to edit the widget." : "Loading...")
                .font(.custom(Constants.muliBold.rawValue,
                              size: 16,
                              relativeTo: .headline))
                .minimumScaleFactor(0.5)
        }.padding()
    }
}
