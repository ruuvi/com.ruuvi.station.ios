import Intents
import RuuviLocalization
import SwiftUI
import WidgetKit

struct SingleSensorWidgetEntryView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    var entry: WidgetEntry
    var familyOverride: WidgetFamily? = nil
    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    var body: some View {
        ZStack {
            if entry.isAuthorized {
                if entry.record == nil {
                    EmptyWidgetView(entry: entry, familyOverride: family)
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
                if family == .systemSmall {
                    SimpleWidgetView(entry: entry)
                } else if family == .accessoryInline {
                    SimpleWidgetViewInline(entry: entry)
                } else if family == .accessoryRectangular {
                    SimpleWidgetViewRectangle(entry: entry)
                } else if family == .accessoryCircular {
                    SimpleWidgetViewCircular(entry: entry)
                } else {
                }
            }
        }
        .containerBackground()
    }
}

public struct RuuviSingleSensorWidget: Widget {
    public init() {}
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
                .systemSmall
            ]
        }
    }

    public var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: RuuviTagSelectionIntent.self,
            provider: WidgetProvider()
        ) { entry in
            SingleSensorWidgetEntryView(entry: entry)
                .environment(\.locale, viewModel.locale())
        }
        .configurationDisplayName(Constants.widgetDisplayName.rawValue)
        .description(RuuviLocalization.Widgets.Description.message)
        .supportedFamilies(supportedFamilies)
        .contentMarginsDisabledIfAvailable()
    }
}

public struct RuuviMultiSensorWidget: Widget {
    public init() {}
    let kind: String = Constants.multiSensorWidgetKindId.rawValue
    let viewModel = WidgetViewModel()

    public var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: RuuviMultiSensorSelectionIntent.self,
            provider: MultiSensorWidgetProvider()
        ) { entry in
            MultiSensorWidgetEntryView(entry: entry)
                .environment(\.locale, viewModel.locale())
        }
        .configurationDisplayName(Constants.widgetDisplayName.rawValue)
        .description(RuuviLocalization.Widgets.Description.message)
        .supportedFamilies([
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
        ])
        .contentMarginsDisabledIfAvailable()
    }
}

extension WidgetConfiguration {
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
    func containerBackground(_ color: Color = .backgroundColor) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) {
                color
            }
        } else {
            self
        }
    }
}

struct RuuviWidgets_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SingleSensorWidgetEntryView(entry: .placeholder())
                .previewContext(WidgetPreviewContext(family: .systemSmall))

            MultiSensorWidgetEntryView(
                entry: .placeholder(for: .systemMedium)
            )
            .previewContext(WidgetPreviewContext(family: .systemMedium))

            MultiSensorWidgetEntryView(
                entry: .placeholder(for: .systemLarge)
            )
            .previewContext(WidgetPreviewContext(family: .systemLarge))
        }
    }
}
