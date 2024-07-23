import SwiftUI

struct SimpleWidgetView: View {
    @Environment(\.canShowWidgetContainerBackground) private var canShowBackground
    private let viewModel = WidgetViewModel()
    var entry: WidgetProvider.Entry
    var body: some View {
        GeometryReader { geometry in
            VStack {
                HStack {
                    Image(Constants.ruuviLogo.rawValue)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width * 0.35, alignment: .leading)
                        .foregroundColor(Color.logoColor)
                    Spacer()
                    if #available(iOSApplicationExtension 17.0, *) {
                        measurementTimeView(for: entry)
                            .invalidatableContent()
                    } else {
                        measurementTimeView(for: entry)
                    }
                }.padding(EdgeInsets(top: 12, leading: 12, bottom: 0, trailing: 12))

                Spacer()

                VStack(spacing: 4) {
                    HStack {
                        Text(entry.tag.displayString)
                            .foregroundColor(Color.sensorNameColor1)
                            .font(.custom(
                                Constants.muliBold.rawValue,
                                size: canShowBackground ? 16 : 22,
                                relativeTo: .headline
                            )
                            )
                            .frame(maxWidth: .infinity, alignment: .bottomLeading)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.5)
                    }

                    HStack(spacing: 2) {
                        Text(viewModel.getValue(
                            from: entry.record,
                            settings: entry.settings,
                            config: entry.config
                        ))
                        .environment(\.locale, viewModel.locale())
                        .foregroundColor(.bodyTextColor)
                        .font(.custom(
                            Constants.oswaldBold.rawValue,
                            size: canShowBackground ? 36 : 66,
                            relativeTo: .largeTitle
                        ))
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .minimumScaleFactor(0.5)
                        Text(viewModel.getUnit(for: WidgetSensorEnum(rawValue: entry.config.sensor.rawValue)))
                            .foregroundColor(Color.unitTextColor)
                            .font(.custom(
                                Constants.oswaldExtraLight.rawValue,
                                size: canShowBackground ? 16 : 24,
                                relativeTo: .title3
                            ))
                            .baselineOffset(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .minimumScaleFactor(0.5)
                        if #available(iOS 17.0, *) {
                            if !entry.isPreview {
                                Button(intent: WidgetRefresher()
                                ) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(Color.sensorNameColor1)
                                        .padding(.top, 12)
                                }
                                .clipShape(Circle())
                                .tint(.clear)
                                .frame(width: 12, height: 12)
                                .padding(0)
                            }
                        }
                    }
                }.padding(EdgeInsets(top: 12, leading: 12, bottom: 8, trailing: 12))
            }.widgetURL(URL(string: "\(entry.tag.identifier.unwrapped)"))
        }
    }

    @ViewBuilder
    private func measurementTimeView(for entry: WidgetEntry) -> some View {
        Text(viewModel.measurementTime(from: entry))
            .foregroundColor(Color.sensorNameColor1)
            .font(.custom(
                Constants.muliRegular.rawValue,
                size: canShowBackground ? 10 : 14,
                relativeTo: .body
            ))
            .minimumScaleFactor(0.5)
    }
}

extension EnvironmentValues {
    var canShowWidgetContainerBackground: Bool {
        if #available(iOSApplicationExtension 15.0, *) {
            self.showsWidgetContainerBackground
        } else {
            false
        }
    }
}
