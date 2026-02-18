import RuuviLocalization
import SwiftUI

@available(iOSApplicationExtension 17.0, *)
struct MultiSensorWidgetEntryView: View {
    var entry: MultiSensorWidgetProvider.Entry

    var body: some View {
        ZStack {
            if !entry.isAuthorized {
                UnauthorizedView()
            } else if entry.sensors.isEmpty {
                MultiSensorEmptyView()
            } else {
                MultiSensorWidgetView(entry: entry)
            }
        }
        .containerBackground()
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct MultiSensorEmptyView: View {
    var body: some View {
        ZStack {
            Color.backgroundColor.edgesIgnoringSafeArea(.all)
        }
        VStack {
            Text(RuuviLocalization.Widgets.Unconfigured.Simple.message)
                .font(.mulish(.bold, size: 14, relativeTo: .subheadline))
                .foregroundColor(.sensorNameColor1)
                .multilineTextAlignment(.center)
        }
        .padding(8)
    }
}

@available(iOSApplicationExtension 17.0, *)
private struct MultiSensorWidgetView: View {
    private enum Layout {
        static let topPadding: CGFloat = 12
        static let bottomPadding: CGFloat = 8
        static let horizontalPadding: CGFloat = 12
        static let sensorSpacing: CGFloat = 10
        static let rowHeight: CGFloat = 20
        static let rowSpacing: CGFloat = 0
        static let valueUnitSpacing: CGFloat = 3
    }

    private let viewModel = WidgetViewModel()
    var entry: MultiSensorWidgetProvider.Entry

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: Layout.sensorSpacing) {
                ForEach(entry.sensors) { sensor in
                    sensorSection(sensor)
                }
            }
            .padding(
                EdgeInsets(
                    top: Layout.topPadding,
                    leading: Layout.horizontalPadding,
                    bottom: Layout.bottomPadding,
                    trailing: Layout.horizontalPadding
                )
            )
        }
        .widgetURL(URL(string: entry.sensors.first?.sensorId ?? ""))
    }

    @ViewBuilder
    private func sensorSection(_ sensor: MultiSensorWidgetSensorItem) -> some View {
        let indicators = viewModel.indicators(
            from: sensor.record,
            settings: sensor.settings,
            cloudSettings: sensor.cloudSettings,
            deviceType: sensor.deviceType,
            selectedCodes: sensor.selectedCodes
        )

        if !indicators.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(sensor.name)
                        .foregroundColor(.sensorNameColor1)
                        .font(.mulish(.extraBold, size: 13, relativeTo: .subheadline))
                        .lineLimit(1)

                    Text(relativeMeasurementTime(from: sensor.record?.date))
                        .foregroundColor(.sensorNameColor2.opacity(0.6))
                        .font(.mulish(.regular, size: 9, relativeTo: .caption2))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }

                if indicators.count < 3 {
                    VStack(alignment: .leading, spacing: Layout.rowSpacing) {
                        ForEach(indicators) { indicator in
                            indicatorRow(indicator)
                                .frame(height: Layout.rowHeight)
                        }
                    }
                } else {
                    let rows = indicators.pairedRowsForMultiSensorWidget()
                    VStack(alignment: .leading, spacing: Layout.rowSpacing) {
                        ForEach(rows.indices, id: \.self) { rowIndex in
                            HStack(spacing: 0) {
                                indicatorRow(rows[rowIndex].0)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if let second = rows[rowIndex].1 {
                                    indicatorRow(second)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Spacer()
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(height: Layout.rowHeight)
                        }
                    }
                }
            }
        }
    }

    private func indicatorRow(_ indicator: WidgetIndicatorDisplayItem) -> some View {
        HStack(spacing: Layout.valueUnitSpacing) {
            Text(indicator.value)
                .font(.mulish(.extraBold, size: 12, relativeTo: .body))
                .foregroundColor(.bodyTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if !indicator.hidesUnit && !indicator.unit.isEmpty {
                Text(indicator.unit)
                    .font(.mulish(.bold, size: 9, relativeTo: .caption2))
                    .foregroundColor(.bodyTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(indicator.title)
                .font(.mulish(.regular, size: 9, relativeTo: .caption2))
                .foregroundColor(.sensorNameColor2.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func relativeMeasurementTime(from date: Date?) -> String {
        guard let date else {
            return RuuviLocalization.Cards.UpdatedLabel.NoData.message
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

@available(iOSApplicationExtension 17.0, *)
private extension Array where Element == WidgetIndicatorDisplayItem {
    func pairedRowsForMultiSensorWidget() -> [(WidgetIndicatorDisplayItem, WidgetIndicatorDisplayItem?)] {
        guard !isEmpty else {
            return []
        }

        var result: [(WidgetIndicatorDisplayItem, WidgetIndicatorDisplayItem?)] = []
        var index = 0

        while index < count {
            let first = self[index]
            let second: WidgetIndicatorDisplayItem? = (index + 1) < count ? self[index + 1] : nil
            result.append((first, second))
            index += 2
        }

        return result
    }
}
