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
            .font(.mulish(.bold, size: 14, relativeTo: .subheadline))
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
        static let sensorCardHorizontalPadding: CGFloat = 10
        static let sensorCardVerticalPadding: CGFloat = 8
        static let sensorCardCornerRadius: CGFloat = 12
        static let sensorCardStrokeOpacity: Double = 0.08
        static let sensorCardFallbackFillOpacity: Double = 0.14
        static let sensorCardFallbackStrokeOpacity: Double = 0.22
        static let sensorCardShadowOpacity: Double = 0.08
        static let sensorCardShadowRadius: CGFloat = 4
        static let sensorCardShadowOffsetY: CGFloat = 2
        static let rowHeight: CGFloat = 20
        static let rowSpacing: CGFloat = 0
        static let valueUnitSpacing: CGFloat = 3
    }

    @Environment(\.widgetFamily) private var family
    @Environment(\.canShowWidgetContainerBackground) private var canShowBackground
    @Environment(\.isFullColorWidgetRenderingMode) private var isFullColorWidgetRenderingMode
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
    // swiftlint:disable:next function_body_length
    private func sensorSection(_ sensor: MultiSensorWidgetSensorItem) -> some View {
        let indicators = viewModel.indicators(
            from: sensor.record,
            settings: sensor.settings,
            cloudSettings: sensor.cloudSettings,
            deviceType: sensor.deviceType,
            selectedCodes: sensor.selectedCodes
        )

        if !indicators.isEmpty {
            let sensorContent = VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(sensor.name)
                        .foregroundColor(.dashboardTitleColor)
                        .font(.mulish(.extraBold, size: 13, relativeTo: .subheadline))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(viewModel.measurementTime(from: sensor.record?.date))
                        .foregroundColor(.sensorNameColor1)
                        .font(.mulish(.regular, size: 10, relativeTo: .body))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
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

            if let deepLink = viewModel.widgetDeepLinkURL(
                sensorId: sensor.sensorId,
                record: sensor.record
            ) {
                Link(destination: deepLink) {
                    sensorCard(sensorContent)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                sensorCard(sensorContent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sensorCard<V: View>(_ content: V) -> some View {
        let shouldDrawDashboardBackground = canShowBackground && isFullColorWidgetRenderingMode
        let cardFillColor = shouldDrawDashboardBackground ?
            Color.dashboardCardBackgroundColor :
            Color.white.opacity(Layout.sensorCardFallbackFillOpacity)
        let cardStrokeColor = shouldDrawDashboardBackground ?
            Color.sensorNameColor2.opacity(Layout.sensorCardStrokeOpacity) :
            Color.white.opacity(Layout.sensorCardFallbackStrokeOpacity)
        let shadowColor = shouldDrawDashboardBackground ?
            Color.black.opacity(Layout.sensorCardShadowOpacity) :
            Color.clear

        return content
            .padding(.horizontal, Layout.sensorCardHorizontalPadding)
            .padding(.vertical, Layout.sensorCardVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Layout.sensorCardCornerRadius)
                    .fill(cardFillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.sensorCardCornerRadius)
                    .stroke(cardStrokeColor)
            )
            .shadow(
                color: shadowColor,
                radius: Layout.sensorCardShadowRadius,
                x: 0,
                y: Layout.sensorCardShadowOffsetY
            )
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

}

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
