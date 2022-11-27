import SwiftUI

struct EmptyWidgetView: View {
    struct Texts {
        let unconfigured = "Widgets.Unconfigured.message"
        let loading = "Widgets.Loading.message"
    }
    private let texts = Texts()
    var entry: WidgetProvider.Entry

    var body: some View {
        ZStack {
            Color.backgroundColor.edgesIgnoringSafeArea(.all)
        }
        VStack {
            Text(entry.config.ruuviWidgetTag == nil ? texts.unconfigured.localized : texts.loading.localized)
                .font(.custom(Constants.muliBold.rawValue,
                              size: 16,
                              relativeTo: .headline))
                .minimumScaleFactor(0.5)
        }.padding()
    }
}
