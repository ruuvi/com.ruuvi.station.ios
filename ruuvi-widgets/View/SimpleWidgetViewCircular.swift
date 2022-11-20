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
        VStack {
            VStack(alignment: .center) {

                Text(entry.record?.date ?? Date(), formatter: DateFormatter.widgetDateFormatter)
                    .environment(\.locale, viewModel.locale())
                    .font(.custom(Constants.muliRegular.rawValue,
                                  size: 6,
                                  relativeTo: .body))
                    .minimumScaleFactor(0.5)
                    .padding(.top, 0)
                viewModel.symbol(from: entry)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 10, height: 10)
                    .padding(.top, -4)

            }.padding(.bottom, -10)

            VStack {
                Text(entry.tag.displayString.substring(toIndex: 8).uppercased())
                    .font(.custom(Constants.muliBold.rawValue,
                                  size: 8,
                                  relativeTo: .body))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .minimumScaleFactor(0.5)

                HStack(spacing: 0) {
                    Text(viewModel.getValue(from: entry.record,
                                            settings: entry.settings,
                                            config: entry.config))
                    .environment(\.locale, viewModel.locale())
                    .foregroundColor(.bodyTextColor)
                    .font(.custom(Constants.oswaldBold.rawValue,
                                  size: 10,
                                  relativeTo: .title))
                    .minimumScaleFactor(0.5)
                    Text(viewModel.getUnit(for: WidgetSensorEnum(rawValue: entry.config.sensor.rawValue)))
                        .foregroundColor(Color.unitTextColor)
                        .font(.custom(Constants.oswaldBold.rawValue,
                                      size: 6,
                                      relativeTo: .body))
                        .baselineOffset(3)
                        .minimumScaleFactor(0.5)
                }
            }.padding(EdgeInsets(top: 4, leading: 8, bottom: 0, trailing: 8))
        }.widgetURL(URL(string: "\(entry.tag.identifier.unwrapped)"))
    }
}
