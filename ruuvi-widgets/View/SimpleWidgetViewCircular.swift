import SwiftUI

@available(iOS 14.0, *)
struct SimpleWidgetViewCircular: View {
    private let viewModel = WidgetViewModel()
    var entry: WidgetProvider.Entry
    var body: some View {
        ZStack {
            Color.backgroundColor
                            .ignoresSafeArea()
        }

        VStack(spacing: 0) {
            Text(entry.tag.displayString.substring(toIndex: 8).capitalized)
                .font(.custom(Constants.muliBold.rawValue,
                              size: 12,
                              relativeTo: .subheadline))
                .foregroundColor(.sensorNameColor1)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(viewModel.getValue(from: entry.record,
                                    settings: entry.settings,
                                    config: entry.config))
            .environment(\.locale, viewModel.locale())
            .foregroundColor(.bodyTextColor)
            .font(.custom(Constants.oswaldBold.rawValue,
                          size: 18,
                          relativeTo: .subheadline))
            .minimumScaleFactor(0.6)
            .padding(.top, -4)

            Text(viewModel.getUnit(for: WidgetSensorEnum(
                rawValue: entry.config.sensor.rawValue)))
                .foregroundColor(Color.unitTextColor)
                .font(.custom(Constants.muliBold.rawValue,
                              size: 8,
                              relativeTo: .body))

                .minimumScaleFactor(0.5)

        }.padding(EdgeInsets(top: 4, leading: 8, bottom: 0, trailing: 8))
            .widgetURL(URL(string: "\(entry.tag.identifier.unwrapped)"))
    }
}
