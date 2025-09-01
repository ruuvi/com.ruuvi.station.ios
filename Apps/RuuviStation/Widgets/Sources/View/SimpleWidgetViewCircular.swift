import SwiftUI
import RuuviLocalization

struct SimpleWidgetViewCircular: View {
    private let viewModel = WidgetViewModel()
    var entry: WidgetProvider.Entry
    var body: some View {
        ZStack {
            Color.backgroundColor.edgesIgnoringSafeArea(.all).clipShape(Circle())
        }

        VStack(spacing: 0) {
            Text(entry.tag.displayString.substring(toIndex: 8).capitalized)
                .font(.mulish(.bold, size: 8, relativeTo: .subheadline))
                .foregroundColor(.sensorNameColor1)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(viewModel.getValue(
                from: entry.record,
                settings: entry.settings,
                config: entry.config
            ))
            .environment(\.locale, viewModel.locale())
            .foregroundColor(.white)
            .font(.oswald(.bold, size: 18, relativeTo: .subheadline))
            .minimumScaleFactor(0.6)
            .padding(.top, -4)

            Text(viewModel.getUnit(for: WidgetSensorEnum(
                rawValue: entry.config.sensor.rawValue)))
                .foregroundColor(Color.unitTextColor)
                .font(.mulish(.bold, size: 10, relativeTo: .body))
                .minimumScaleFactor(0.5)
                .padding(.top, -2)

        }.padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
            .widgetURL(URL(string: "\(entry.tag.identifier.unwrapped)"))
    }
}
