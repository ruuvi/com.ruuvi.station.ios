import SwiftUI

struct UnauthorizedView: View {
    @Environment(\.widgetFamily) private var family
    struct Texts {
        let unauthorizedRegular = "Widgets.Unauthorized.Regular.message"
        let unauthorizedSmall = "SignIn.Title.text"
        let unauthorizedInline = "Widgets.Unauthorized.Inline.message"
    }

    private let texts = Texts()

    var body: some View {
        if family == .systemSmall {
            RegularUnauthorizedWidgetView()
        } else {
            if #available(iOSApplicationExtension 16.0, *) {
                if family == .accessoryCircular {
                    CircularUnauthorizedWidgetView()
                } else if family == .accessoryInline {
                    InlineUnauthorizedWidgetView()
                } else if family == .accessoryRectangular {
                    RegularUnauthorizedWidgetView()
                }
            }
        }
    }

    // Unauthorized view for small and rectangular widget.
    struct RegularUnauthorizedWidgetView: View {
        @Environment(\.widgetFamily) private var family
        private let texts = Texts()

        var body: some View {
            ZStack {
                Color.backgroundColor.edgesIgnoringSafeArea(.all)
            }
            .cornerRadius(8)
            VStack {
                Text(texts.unauthorizedRegular.localized)
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

    // Unauthorized view circular
    struct CircularUnauthorizedWidgetView: View {
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
                    .padding([.leading, .trailing], 8)
                    .padding(.bottom, -4)
                Text(texts.unauthorizedSmall.localized)
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

    // Unauthorized view inline
    struct InlineUnauthorizedWidgetView: View {
        private let texts = Texts()

        var body: some View {
            ZStack {
                Color.backgroundColor.edgesIgnoringSafeArea(.all)
            }

            Text(texts.unauthorizedInline.localized)
        }
    }
}
