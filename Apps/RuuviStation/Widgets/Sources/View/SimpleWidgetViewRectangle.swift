import SwiftUI
import RuuviLocalization

struct SimpleWidgetViewRectangle: View {
    private let viewModel = WidgetViewModel()
    var entry: WidgetProvider.Entry
    var body: some View {
        VStack {
            VStack {
                Text(entry.tag.displayString.capitalized)
                    .font(.mulish(.bold, size: 16, relativeTo: .subheadline))
                    .foregroundColor(Color.sensorNameColor1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
                    .padding(.top, 10)

                HStack(spacing: 2) {
                    Text(viewModel.getValue(
                        from: entry.record,
                        settings: entry.settings,
                        config: entry.config
                    ))
                    .environment(\.locale, viewModel.locale())
                    .foregroundColor(.bodyTextColor)
                    .font(.oswald(.bold, size: 30, relativeTo: .title))
                    Text(
                        viewModel.getUnit(from: entry.config)
                    )
                    .foregroundColor(Color.unitTextColor)
                    .font(.oswald(.extraLight, size: 18, relativeTo: .title3))
                    .baselineOffset(8)
                    Spacer()
                }
                .padding(EdgeInsets(
                    top: -20,
                    leading: 4,
                    bottom: 8,
                    trailing: 4
                ))
            }
        }.edgesIgnoringSafeArea(.all)
            .widgetURL(URL(string: "\(entry.tag.identifier.unwrapped)"))
    }
}
