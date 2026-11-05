import WidgetKit
import SwiftUI
import RuuviLocalization

struct EmptyWidgetView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    struct Texts {
        let messageSimple = RuuviLocalization.Widgets.Unconfigured.Simple.message
        let messageRectangular = RuuviLocalization.Widgets.Unconfigured.Rectangular.message
        let messageCircular = RuuviLocalization.Widgets.Unconfigured.Circular.message
        let messageInline = RuuviLocalization.Widgets.Unconfigured.Inline.message
        let loading = RuuviLocalization.Widgets.Loading.message
    }

    private let texts = Texts()
    var entry: WidgetEntry
    var familyOverride: WidgetFamily? = nil
    private var family: WidgetFamily { familyOverride ?? environmentFamily }

    var body: some View {
        if family == .systemSmall {
            RegularEmptyWidgetView(entry: entry, isSimple: true)
        } else {
            if #available(iOSApplicationExtension 16.0, *) {
                if family == .accessoryCircular {
                    CircularEmptyWidgetView(entry: entry)
                } else if family == .accessoryInline {
                    InlineEmptyWidgetView(entry: entry)
                } else if family == .accessoryRectangular {
                    RegularEmptyWidgetView(entry: entry, isSimple: false)
                }
            }
        }
    }

    // Empty view for small and rectangular widget.
    struct RegularEmptyWidgetView: View {
        var entry: WidgetEntry
        var isSimple: Bool
        private let texts = Texts()

        var body: some View {
            ZStack {
                Color.backgroundColor.edgesIgnoringSafeArea(.all)
                Text(
                    entry.config.sensorId == nil
                        ? (isSimple ? texts.messageSimple : texts.messageRectangular)
                        : texts.loading
                )
                .font(
                    .mulish(
                        .bold,
                        size: isSimple ? 16 : 10,
                        relativeTo: .subheadline
                    )
                )
                .foregroundColor(.sensorNameColor1)
                .multilineTextAlignment(.center)
                .padding(4)
            }
            .cornerRadius(8)
        }
    }

    // Empty view circular
    struct CircularEmptyWidgetView: View {
        var entry: WidgetEntry
        private let texts = Texts()

        var body: some View {
            ZStack {
                Color.backgroundColor.edgesIgnoringSafeArea(.all).clipShape(Circle())
                VStack {
                    Image(Constants.ruuviLogo.rawValue, bundle: WidgetResources.bundle)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(
                            .init(
                                top: 4,
                                leading: 8,
                                bottom: -4,
                                trailing: 8
                            ))
                    Text(entry.config.sensorId == nil ? texts.messageCircular : texts.loading)
                        .font(.mulish(.bold, size: 8, relativeTo: .headline))
                        .foregroundColor(.sensorNameColor1)
                        .multilineTextAlignment(.center)
                }
                .padding(4)
            }
        }
    }

    // Empty view inline
    struct InlineEmptyWidgetView: View {
        var entry: WidgetEntry
        private let texts = Texts()

        var body: some View {
            ZStack {
                Color.backgroundColor.edgesIgnoringSafeArea(.all)
                Text(entry.config.sensorId == nil ? texts.messageInline : texts.loading)
            }
        }
    }
}
