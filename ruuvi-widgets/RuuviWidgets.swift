import WidgetKit
import SwiftUI
import Intents

@available(iOS 14.0, *)
struct RuuviWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WidgetProvider.Entry

    var body: some View {
        ZStack {
            if entry.isAuthorized {
                if entry.record == nil {
                    EmptyWidgetView(entry: entry)
                } else {
                    if family == .systemSmall {
                        SimpleWidgetView(entry: entry)
                    } else if #available(iOSApplicationExtension 16.0, *) {
                        if family == .accessoryInline {
                            SimpleWidgetViewInline(entry: entry)
                        } else if family == .accessoryRectangular {
                            SimpleWidgetViewRectangle(entry: entry)
                        } else if family == .accessoryCircular {
                            SimpleWidgetViewCircular(entry: entry)
                        } else {}
                    } else {}
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
    private var supportedFamilies: [WidgetFamily] {
        if #available(iOSApplicationExtension 16.0, *) {
            return [
                .systemSmall,
                .accessoryRectangular,
                .accessoryInline,
                .accessoryCircular
            ]
        } else {
            return [
                .systemSmall
            ]
        }
    }

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind,
                            intent: RuuviTagSelectionIntent.self,
                            provider: WidgetProvider()) { entry in
            RuuviWidgetEntryView(entry: entry)
                .environment(\.locale, viewModel.locale())
        }
                            .configurationDisplayName(Constants.simpleWidgetDisplayName.rawValue)
                            .description(LocalizedStringKey("Widgets.Description.message"))
                            .supportedFamilies(supportedFamilies)
    }
}

@available(iOS 14.0, *)
struct RuuviWidgets_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOSApplicationExtension 16.0, *) {
            RuuviWidgetEntryView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
        } else {
            RuuviWidgetEntryView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}
