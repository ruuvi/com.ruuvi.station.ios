import SwiftUI
import Localize_Swift

struct EmptyWidgetView: View {
    struct Texts {
        let unconfigured = "Widgets.Unconfigured.message".localized()
        let loading = "Widgets.Loading.message".localized()
    }
    private let texts = Texts()
    var entry: WidgetProvider.Entry

    var body: some View {
        VStack {
            Text(entry.config.ruuviWidgetTag == nil ? texts.unconfigured : texts.loading)
                .font(.custom(Constants.muliBold.rawValue,
                              size: 16,
                              relativeTo: .headline))
                .minimumScaleFactor(0.5)
        }.padding()
    }
}
