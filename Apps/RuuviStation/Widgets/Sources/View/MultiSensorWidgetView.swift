import RuuviLocalization
import SwiftUI

struct MultiSensorWidgetEntryView: View {
    private enum Layout {
        static let refreshButtonSize: CGFloat = 12
        static let refreshTrailingPadding: CGFloat = 12
        static let refreshBottomPadding: CGFloat = 16
    }

    @Environment(\.canShowWidgetContainerBackground) private var canShowBackground
    @Environment(\.isFullColorWidgetRenderingMode) private var isFullColorWidgetRenderingMode
    var entry: MultiSensorWidgetEntry

    var body: some View {
        let shouldDrawDashboardBackground = canShowBackground && isFullColorWidgetRenderingMode

        ZStack(alignment: .bottomTrailing) {
            if shouldDrawDashboardBackground {
                Color.dashboardBackgroundColor
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .topLeading) {
                    Group {
                        if entry.sensors.isEmpty {
                            MultiSensorEmptyView()
                        } else {
                            MultiSensorWidgetView(entry: entry)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .clipped()
                }

            if !entry.isPreview, !entry.sensors.isEmpty {
                if #available(iOSApplicationExtension 17.0, *) {
                    Button(intent: WidgetRefresher(target: .multi)) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.sensorNameColor1)
                    }
                    .clipShape(Circle())
                    .tint(.clear)
                    .frame(width: Layout.refreshButtonSize, height: Layout.refreshButtonSize)
                    .padding(.trailing, Layout.refreshTrailingPadding)
                    .padding(.bottom, Layout.refreshBottomPadding)
                }
            }
        }
        .containerBackground(.dashboardBackgroundColor)
    }
}

private struct MultiSensorEmptyView: View {
    var body: some View {
        Text(RuuviLocalization.Widgets.Unconfigured.Simple.message)
            .font(.mulish(.bold, size: 16, relativeTo: .subheadline))
            .foregroundColor(.sensorNameColor1)
            .multilineTextAlignment(.center)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MultiSensorWidgetView: View {
    private enum Layout {
        static let topPadding: CGFloat = 12
        static let bottomPadding: CGFloat = 8
        static let horizontalPadding: CGFloat = 12
        static let sensorSpacing: CGFloat = 10
    }

    @Environment(\.widgetFamily) private var family
    private let viewModel = WidgetViewModel()
    var entry: MultiSensorWidgetEntry

    var body: some View {
        content
        .padding(
            EdgeInsets(
                top: Layout.topPadding,
                leading: Layout.horizontalPadding,
                bottom: Layout.bottomPadding,
                trailing: Layout.horizontalPadding
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var content: some View {
        if family == .systemExtraLarge {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Layout.sensorSpacing, alignment: .top),
                    GridItem(.flexible(), spacing: Layout.sensorSpacing, alignment: .top),
                ],
                alignment: .leading,
                spacing: Layout.sensorSpacing
            ) {
                ForEach(entry.sensors) { sensor in
                    sensorSection(sensor)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Layout.sensorSpacing) {
                ForEach(entry.sensors) { sensor in
                    sensorSection(sensor)
                }
            }
        }
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
            let items = indicators.map { indicator in
                SensorMeasurementItem(
                    id: indicator.id,
                    value: indicator.value,
                    unit: indicator.hidesUnit ? "" : indicator.unit,
                    label: indicator.title
                )
            }
            let card = SensorCardView(
                displayName: sensor.name,
                formattedUpdatedAt: viewModel.measurementTime(from: sensor.record?.date),
                items: items
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            if let deepLink = viewModel.widgetDeepLinkURL(
                sensorId: sensor.sensorId,
                record: sensor.record
            ) {
                Link(destination: deepLink) { card }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                card
            }
        }
    }

}

