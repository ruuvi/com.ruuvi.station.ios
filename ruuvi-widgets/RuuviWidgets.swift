import WidgetKit
import SwiftUI
import Intents

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
        }.containerBackground()
    }
}

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
        IntentConfiguration(
            kind: kind,
            intent: RuuviTagSelectionIntent.self,
            provider: WidgetProvider()
        ) { entry in
            RuuviWidgetEntryView(entry: entry)
                .environment(\.locale, viewModel.locale())
        }.configurationDisplayName(Constants.simpleWidgetDisplayName.rawValue)
            .description(LocalizedStringKey("Widgets.Description.message"))
            .supportedFamilies(supportedFamilies)
            .contentMarginsDisabledIfAvailable()
    }
}

extension WidgetConfiguration {
    func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
        if #available(iOSApplicationExtension 17.0, *) {
            return self.contentMarginsDisabled()
        } else {
            return self
        }
    }
}

extension View {
    @ViewBuilder
    func containerBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                Color.backgroundColor
            }
        } else {
            self
        }
    }
}

struct RuuviWidgets_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOSApplicationExtension 16.0, *) {
            RuuviWidgetEntryView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
        } else if #available(iOSApplicationExtension 17.0, *) {
            RuuviWidgetEntryView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        } else {
            RuuviWidgetEntryView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}
