import SwiftUI

struct EmptyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    struct Texts {
        let messageSimple = "Widgets.Unconfigured.Simple.message"
        let messageRectangular = "Widgets.Unconfigured.Rectangular.message"
        let messageCircular = "Widgets.Unconfigured.Circular.message"
        let messageInline = "Widgets.Unconfigured.Inline.message"
        let loading = "Widgets.Loading.message"
    }

    private let texts = Texts()
    var entry: WidgetProvider.Entry

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
        @Environment(\.widgetFamily) private var family
        var entry: WidgetProvider.Entry
        var isSimple: Bool
        private let texts = Texts()

        var body: some View {
            ZStack {
                Color.backgroundColor.edgesIgnoringSafeArea(.all)
            }
            .cornerRadius(8)
            VStack {
                Text(entry.config.ruuviWidgetTag == nil ?
                    (isSimple ? texts.messageSimple.localized :
                        texts.messageRectangular.localized)
                    : texts.loading.localized)
                    .font(.custom(
                        Constants.muliBold.rawValue,
                        size: family == .systemSmall ? 16 : 10,
                        relativeTo: .subheadline
                    ))
                    .foregroundColor(.sensorNameColor1)
                    .multilineTextAlignment(.center)
            }.padding(4)
        }
    }

    // Empty view circular
    struct CircularEmptyWidgetView: View {
        var entry: WidgetProvider.Entry
        private let texts = Texts()

        var body: some View {
            ZStack {
                Color.backgroundColor.edgesIgnoringSafeArea(.all).clipShape(Circle())
            }

            VStack {
                Image(Constants.ruuviLogo.rawValue)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.init(
                        top: 4,
                        leading: 8,
                        bottom: -4,
                        trailing: 8
                    ))
                Text(entry.config.ruuviWidgetTag == nil ?
                    texts.messageCircular.localized : texts.loading.localized)
                    .font(.custom(
                        Constants.muliBold.rawValue,
                        size: 8,
                        relativeTo: .headline
                    ))
                    .foregroundColor(.sensorNameColor1)
                    .multilineTextAlignment(.center)
            }.padding(4)
        }
    }

    // Empty view inline
    struct InlineEmptyWidgetView: View {
        var entry: WidgetProvider.Entry
        private let texts = Texts()

        var body: some View {
            ZStack {
                Color.backgroundColor.edgesIgnoringSafeArea(.all)
            }
            Text(entry.config.ruuviWidgetTag == nil ?
                texts.messageInline.localized : texts.loading.localized)
        }
    }
}
