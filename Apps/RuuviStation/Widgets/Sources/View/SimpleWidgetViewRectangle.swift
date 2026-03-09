import SwiftUI
import RuuviLocalization

struct SimpleWidgetViewRectangle: View {
    private let viewModel = WidgetViewModel()
    var entry: WidgetProvider.Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.tag.displayString.capitalized)
                .font(.mulish(.bold, size: 13, relativeTo: .subheadline))
                .foregroundColor(Color.sensorNameColor1)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let sensorName = viewModel.getSensor(from: entry.config)?.displayName() {
                Text(sensorName)
                    .font(.mulish(.regular, size: 10, relativeTo: .caption))
                    .foregroundColor(Color.sensorNameColor1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            HStack(alignment: .center, spacing: 2) {
                Text(viewModel.getValue(
                    from: entry.record,
                    settings: entry.settings,
                    config: entry.config
                ))
                .environment(\.locale, viewModel.locale())
                .foregroundColor(.bodyTextColor)
                .font(.oswald(.bold, size: 24, relativeTo: .title))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                Text(
                    viewModel
                        .getUnit(
                            for: viewModel.getSensor(from: entry.config)
                        )
                )
                .foregroundColor(Color.unitTextColor)
                .font(.oswald(.extraLight, size: 10, relativeTo: .caption))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
        }
        .padding(.horizontal, 4)
        .edgesIgnoringSafeArea(.all)
        .widgetURL(URL(string: "\(entry.tag.identifier.unwrapped)"))
    }
}
