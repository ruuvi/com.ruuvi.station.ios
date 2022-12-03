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
                    .frame(width: 12, height: 12)

                Text(viewModel.measurementTime(from: entry))
                    .font(.custom(Constants.muliRegular.rawValue,
                                  size: 12,
                                  relativeTo: .body))
                    .minimumScaleFactor(0.5)
                    .padding(.leading, -2)

                Spacer()
            }.padding(EdgeInsets(top: 12,
                                 leading: 4,
                                 bottom: -2,
                                 trailing: 0))

            VStack {
                Text(entry.tag.displayString.uppercased())
                    .font(.custom(Constants.muliBold.rawValue,
                                  size: 12,
                                  relativeTo: .subheadline))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.5)
                    .padding(.leading, 4)

                HStack(spacing: 2) {
                    viewModel.symbol(from: entry)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 15, height: 15)
                        .padding(.trailing, 2)

                    Text(viewModel.getValue(from: entry.record,
                                            settings: entry.settings,
                                            config: entry.config))
                    .environment(\.locale, viewModel.locale())
                    .foregroundColor(.bodyTextColor)
                    .font(.custom(Constants.oswaldBold.rawValue,
                                  size: 28,
                                  relativeTo: .title))
                    .minimumScaleFactor(0.5)
                    Text(viewModel.getUnit(for: WidgetSensorEnum(rawValue: entry.config.sensor.rawValue)))
                        .foregroundColor(Color.unitTextColor)
                        .font(.custom(Constants.oswaldBold.rawValue,
                                      size: 16,
                                      relativeTo: .title3))
                        .baselineOffset(8)
                        .minimumScaleFactor(0.5)
                    Spacer()
                }.padding(EdgeInsets(top: -10,
                                     leading: 4,
                                     bottom: 14,
                                     trailing: 4))
            }
        }.edgesIgnoringSafeArea(.all)
        .widgetURL(URL(string: "\(entry.tag.identifier.unwrapped)"))
    }
}
