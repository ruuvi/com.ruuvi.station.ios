import AppIntents
import Intents
import RuuviLocalization
import SwiftUI
import WidgetKit

struct SingleSensorWidgetEntryView: View {
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
                    } else if family == .accessoryInline {
                        SimpleWidgetViewInline(entry: entry)
                    } else if family == .accessoryRectangular {
                        SimpleWidgetViewRectangle(entry: entry)
                    } else if family == .accessoryCircular {
                        SimpleWidgetViewCircular(entry: entry)
                    } else {
                        EmptyView()
                    }
                }
            } else {
                UnauthorizedView()
            }
        }
        .containerBackground()
    }
}

struct RuuviSingleSensorWidget: Widget {
    let kind: String = Constants.simpleWidgetKindId.rawValue
    let viewModel = WidgetViewModel()

    private var supportedFamilies: [WidgetFamily] {
        if #available(iOSApplicationExtension 16.0, *) {
            [
                .systemSmall,
                .accessoryRectangular,
                .accessoryInline,
                .accessoryCircular,
            ]
        } else {
            [
                .systemSmall,
            ]
        }
    }

    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: RuuviTagSelectionIntent.self,
            provider: WidgetProvider()
        ) { entry in
            SingleSensorWidgetEntryView(entry: entry)
                .environment(\.locale, viewModel.locale())
        }
        .configurationDisplayName(Constants.simpleWidgetDisplayName.rawValue)
        .description(RuuviLocalization.Widgets.Description.message)
        .supportedFamilies(supportedFamilies)
        .keepWidgetBackgroundIfAvailable()
        .contentMarginsDisabledIfAvailable()
    }
}

@available(iOSApplicationExtension 17.0, *)
struct RuuviMultiSensorWidget: Widget {
    let kind: String = Constants.multiSensorWidgetKindId.rawValue
    let viewModel = WidgetViewModel()

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: MultiSensorWidgetConfigurationIntent.self,
            provider: MultiSensorWidgetProvider()
        ) { entry in
            MultiSensorWidgetEntryView(entry: entry)
                .environment(\.locale, viewModel.locale())
        }
        .configurationDisplayName(Constants.multiSensorWidgetDisplayName.rawValue)
        .description(RuuviLocalization.Widgets.Description.message)
        .supportedFamilies([
            .systemMedium,
            .systemLarge,
        ])
        .keepWidgetBackgroundIfAvailable()
        .contentMarginsDisabledIfAvailable()
    }
}

@main
struct RuuviWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        RuuviSingleSensorWidget()
        if #available(iOSApplicationExtension 17.0, *) {
            RuuviMultiSensorWidget()
        }
    }
}

extension WidgetConfiguration {
    func keepWidgetBackgroundIfAvailable() -> some WidgetConfiguration {
        if #available(iOSApplicationExtension 17.0, *) {
            // swiftformat:disable all
            return self.containerBackgroundRemovable(false)
        } else {
            return self
            // swiftformat:enable all
        }
    }

    func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
        if #available(iOSApplicationExtension 17.0, *) {
            // swiftformat:disable all
            return self.contentMarginsDisabled()
        } else {
            return self
            // swiftformat:enable all
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
        SingleSensorWidgetEntryView(entry: .placeholder())
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
