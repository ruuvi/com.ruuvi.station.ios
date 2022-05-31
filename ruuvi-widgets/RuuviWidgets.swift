import WidgetKit
import SwiftUI
import Intents

@available(iOS 14.0, *)
struct RuuviWidgetEntryView: View {
    var entry: WidgetProvider.Entry

    var body: some View {
        ZStack {
            Color.backgroundColor
                .ignoresSafeArea()
            if entry.isAuthorized {
                if entry.record == nil {
                    EmptyWidgetView(entry: entry)
                } else {
                    SimpleWidgetView(entry: entry)
                }
            } else {
                UnauthorizedView()
            }
        }
    }
}

@available(iOS 14.0, *)
@main
struct RuuviWidgets: Widget {
    let kind: String = Constants.simpleWidgetKindId.rawValue
    let viewModel = WidgetViewModel()
    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind,
                            intent: RuuviTagSelectionIntent.self,
                            provider: WidgetProvider()) { entry in
            RuuviWidgetEntryView(entry: entry)
                .environment(\.locale, viewModel.locale())
        }
                            .configurationDisplayName(Constants.simpleWidgetDisplayName.rawValue)
                            .description(LocalizedStringKey("Widgets.Description.message"))
                            .supportedFamilies([.systemSmall])
    }
}

@available(iOS 14.0, *)
struct RuuviWidgets_Previews: PreviewProvider {
    static var previews: some View {
        RuuviWidgetEntryView(entry: .placeholder())
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
