import SwiftUI

@available(iOS 14.0, *)
struct SimpleWidgetViewRectangle: View {
    private let viewModel = WidgetViewModel()
    var entry: WidgetProvider.Entry
    var body: some View {
        VStack {
            HStack {
                Image(Constants.ruuviLogoEye.rawValue)
                    .renderingMode(.original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)

                Text(entry.record?.date ?? Date(), formatter: DateFormatter.widgetDateFormatter)
                    .environment(\.locale, viewModel.locale())
                    .font(.custom(Constants.muliRegular.rawValue,
                                  size: 12,
                                  relativeTo: .body))
                    .minimumScaleFactor(0.5)

                Spacer()
            }.padding(EdgeInsets(top: 4,
                                 leading: 4,
                                 bottom: -8,
                                 trailing: 4))

            VStack {
                Text(entry.tag.displayString.uppercased())
                    .font(.custom(Constants.muliBold.rawValue,
                                  size: 12,
                                  relativeTo: .headline))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.5)

                HStack(spacing: 2) {
                    Text(viewModel.getValue(from: entry.record,
                                            settings: entry.settings,
                                            config: entry.config))
                    .environment(\.locale, viewModel.locale())
                    .foregroundColor(.bodyTextColor)
                    .font(.custom(Constants.oswaldBold.rawValue,
                                  size: 32,
                                  relativeTo: .title))
                    .minimumScaleFactor(0.5)
                    Text(viewModel.getUnit(for: WidgetSensorEnum(rawValue: entry.config.sensor.rawValue)))
                        .foregroundColor(Color.unitTextColor)
                        .font(.custom(Constants.oswaldBold.rawValue,
                                      size: 20,
                                      relativeTo: .title3))
                        .baselineOffset(8)
                        .minimumScaleFactor(0.5)
                    Spacer()
                }
            }.padding(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
        }.widgetURL(URL(string: "\(entry.tag.identifier.unwrapped)"))
    }
}
