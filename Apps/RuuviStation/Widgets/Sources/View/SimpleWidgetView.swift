import RuuviLocalization
import RuuviOntology
import SwiftUI

struct SimpleWidgetView: View {
    @Environment(\.canShowWidgetContainerBackground) private var canShowBackground
    private let viewModel = WidgetViewModel()
    var entry: WidgetProvider.Entry
    var body: some View {
        GeometryReader { geometry in
            VStack {
                HStack {
                    Image(Constants.ruuviLogo.rawValue)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width * 0.35, alignment: .leading)
                        .foregroundColor(Color.logoColor)
                    Spacer()
                    measurementTimeView(for: entry)
                }.padding(EdgeInsets(top: 12, leading: 12, bottom: 0, trailing: 12))

                Spacer()

                VStack(spacing: 4) {
                    HStack {
                        Text(entry.tag.displayString)
                            .foregroundColor(Color.sensorNameColor1)
                            .font(.mulish(.bold, size: canShowBackground ? 16 : 22, relativeTo: .headline))
                            .frame(maxWidth: .infinity, alignment: .bottomLeading)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.5)
                    }

                    HStack(spacing: 2) {
                        Text(viewModel.getValue(
                            from: entry.record,
                            settings: entry.settings,
                            config: entry.config
                        ))
                        .environment(\.locale, viewModel.locale())
                        .foregroundColor(.bodyTextColor)
                        .font(.oswald(.bold, size: canShowBackground ? 30 : 66, relativeTo: .largeTitle))
                        .frame(alignment: .bottomLeading)
                        .minimumScaleFactor(0.5)
                        Text(
                            viewModel.getUnit(from: entry.config)
                        )
                        .foregroundColor(Color.unitTextColor)
                        .font(
                            .oswald(
                                .extraLight,
                                size: canShowBackground ? 14 : 24,
                                relativeTo: .title3
                            )
                        )
                        .baselineOffset(10)
                        .frame(alignment: .topLeading)
                        .minimumScaleFactor(0.5)
                        Spacer()
                        if #available(iOS 17.0, *) {
                            if !entry.isPreview {
                                Button(intent: WidgetRefresher()
                                ) {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(Color.sensorNameColor1)
                                        .padding(.top, 12)
                                }
                                .clipShape(Circle())
                                .tint(.clear)
                                .frame(width: 12, height: 12)
                                .padding(0)
                            }
                        }
                    }
                }.padding(EdgeInsets(top: 12, leading: 12, bottom: 8, trailing: 12))
            }.widgetURL(URL(string: "\(entry.tag.identifier.unwrapped)"))
        }
    }

    @ViewBuilder
    private func measurementTimeView(for entry: WidgetEntry) -> some View {
        Text(viewModel.measurementTime(from: entry))
            .foregroundColor(Color.sensorNameColor1)
            .font(
                .mulish(
                    .regular,
                    size: canShowBackground ? 10 : 14,
                    relativeTo: .body
                )
            )
            .minimumScaleFactor(0.5)
    }
}

extension EnvironmentValues {
    var canShowWidgetContainerBackground: Bool {
        if #available(iOSApplicationExtension 15.0, *) {
            self.showsWidgetContainerBackground
        } else {
            false
        }
    }
}

struct SimpleWidgetViewLarge: View {
    private enum Layout {
        static let topPadding: CGFloat = 12
        static let bottomPadding: CGFloat = 4
        static let leadingPadding: CGFloat = 16
        static let trailingPadding: CGFloat = 10

        static let headerToGridSpacing: CGFloat = 10
        static let gridToFooterSpacing: CGFloat = 8
        static let footerHeight: CGFloat = 24

        static let rowHeight: CGFloat = 20
        static let rowSpacing: CGFloat = 0

        static let rowValueUnitSpacing: CGFloat = 3
        static let pageSpacing: CGFloat = 12

        static let nonGridHeight: CGFloat = 86
    }

    private let viewModel = WidgetViewModel()
    var entry: WidgetProvider.Entry

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                headerView

                indicatorsView(in: geometry.size)
                    .padding(.top, Layout.headerToGridSpacing)

                Spacer(minLength: Layout.gridToFooterSpacing)

                footerView
            }
            .padding(
                EdgeInsets(
                    top: Layout.topPadding,
                    leading: Layout.leadingPadding,
                    bottom: Layout.bottomPadding,
                    trailing: Layout.trailingPadding
                )
            )
            .widgetURL(URL(string: "\(entry.tag.identifier.unwrapped)"))
        }
    }

    private var headerView: some View {
        Text(entry.tag.displayString)
            .foregroundColor(Color.sensorNameColor1)
            .font(.mulish(.extraBold, size: 16, relativeTo: .headline))
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func indicatorsView(in size: CGSize) -> some View {
        let indicators = viewModel.largeWidgetIndicators(from: entry)

        if indicators.isEmpty {
            Spacer(minLength: 0)
        } else {
            let pages = pagedIndicators(
                indicators,
                size: size
            )

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Layout.pageSpacing) {
                    ForEach(pages.indices, id: \.self) { index in
                        indicatorGrid(pageIndicators: pages[index])
                            .frame(
                                width: size.width - Layout.leadingPadding - Layout.trailingPadding,
                                alignment: .leading
                            )
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func indicatorGrid(
        pageIndicators: [WidgetIndicatorDisplayItem]
    ) -> some View {
        if pageIndicators.count < 3 {
            VStack(alignment: .leading, spacing: Layout.rowSpacing) {
                ForEach(pageIndicators) { indicator in
                    indicatorRow(indicator)
                        .frame(height: Layout.rowHeight)
                }
            }
        } else {
            let rows = pageIndicators.pairedRows()
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

    private func indicatorRow(_ indicator: WidgetIndicatorDisplayItem) -> some View {
        HStack(spacing: Layout.rowValueUnitSpacing) {
            Text(indicator.value)
                .font(.mulish(.extraBold, size: 14, relativeTo: .body))
                .foregroundColor(.bodyTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if !indicator.hidesUnit && !indicator.unit.isEmpty {
                Text(indicator.unit)
                    .font(.mulish(.bold, size: 10, relativeTo: .caption2))
                    .foregroundColor(.bodyTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(indicator.title)
                .font(.mulish(.regular, size: 10, relativeTo: .caption2))
                .foregroundColor(.sensorNameColor2.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footerView: some View {
        HStack(spacing: 4) {
            if let source = entry.record?.source,
               let sourceAsset = sourceAsset(for: source) {
                sourceAsset.asset.swiftUIImage
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: sourceAsset.width, height: Layout.footerHeight)
                    .foregroundColor(.sensorNameColor2.opacity(0.8))
                    .opacity(0.7)
            }

            Text(viewModel.relativeMeasurementTime(from: entry))
                .foregroundColor(.sensorNameColor2.opacity(0.5))
                .font(.mulish(.regular, size: 10, relativeTo: .caption))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)
        }
        .frame(height: Layout.footerHeight)
    }

    private func sourceAsset(
        for source: RuuviTagSensorRecordSource
    ) -> (asset: ImageAsset, width: CGFloat)? {
        switch source {
        case .unknown:
            return nil
        case .advertisement, .bgAdvertisement:
            return (RuuviAsset.iconBluetooth, 16)
        case .heartbeat, .log:
            return (RuuviAsset.iconBluetoothConnected, 16)
        case .ruuviNetwork:
            return (RuuviAsset.iconGateway, 22)
        }
    }

    private func pagedIndicators(
        _ indicators: [WidgetIndicatorDisplayItem],
        size: CGSize
    ) -> [[WidgetIndicatorDisplayItem]] {
        guard !indicators.isEmpty else {
            return []
        }

        let availableHeight = max(0, size.height - Layout.nonGridHeight)
        let rowsPerPage = max(
            1,
            Int(
                floor(
                    availableHeight / max(Layout.rowHeight + Layout.rowSpacing, 1)
                )
            )
        )

        let indicatorsPerPage: Int
        if indicators.count < 3 {
            indicatorsPerPage = rowsPerPage
        } else {
            indicatorsPerPage = rowsPerPage * 2
        }

        if indicators.count <= indicatorsPerPage {
            return [indicators]
        }

        return indicators.chunked(into: indicatorsPerPage)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else {
            return [self]
        }

        var chunks: [[Element]] = []
        var index = 0

        while index < count {
            let end = Swift.min(index + size, count)
            chunks.append(Array(self[index..<end]))
            index += size
        }

        return chunks
    }
}

private extension Array where Element == WidgetIndicatorDisplayItem {
    func pairedRows() -> [(WidgetIndicatorDisplayItem, WidgetIndicatorDisplayItem?)] {
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
