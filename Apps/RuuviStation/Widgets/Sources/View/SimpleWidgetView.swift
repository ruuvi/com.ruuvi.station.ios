import RuuviLocalization
import RuuviOntology
import SwiftUI
import WidgetKit

struct SimpleWidgetView: View {
    @Environment(\.canShowWidgetContainerBackground) private var canShowBackground
    private let viewModel = WidgetViewModel()
    var entry: WidgetEntry
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(entry.tag.displayString)
                    .foregroundColor(.bodyTextColor)
                    .font(.mulish(.bold, size: canShowBackground ? 16 : 22, relativeTo: .headline))
                    .frame(maxWidth: .infinity, alignment: .bottomLeading)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.5)
            }

            Spacer(minLength: 8)

            HStack {
                measurementContent
                Spacer()
            }
            .overlay(alignment: .bottomTrailing) {
                if #available(iOS 17.0, *) {
                    if !entry.isPreview {
                        Button(intent: WidgetRefresher(target: .simple)
                        ) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(Color.sensorNameColor1)
                        }
                        .clipShape(Circle())
                        .tint(.clear)
                        .frame(width: 12, height: 12)
                        .padding(.bottom, 6)
                        .padding(.trailing, 6)
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        .widgetURL(
            viewModel.widgetDeepLinkURL(
                sensorId: entry.tag.identifier,
                record: entry.record
            )
        )
    }

    @ViewBuilder
    private var measurementContent: some View {
        if viewModel.isAirQualitySelection(entry.config) {
            airQualityContent
        } else {
            defaultMeasurementContent
        }
    }

    private var defaultMeasurementContent: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text(viewModel.getValue(
                    from: entry.record,
                    settings: entry.settings,
                    config: entry.config
                ))
                .environment(\.locale, viewModel.locale())
                .foregroundColor(.bodyTextColor)
                .font(.oswald(.bold, size: canShowBackground ? 40 : 76, relativeTo: .largeTitle))
                .frame(alignment: .bottomLeading)
                .minimumScaleFactor(0.8)
                Text(
                    viewModel.getUnit(from: entry.config)
                )
                .foregroundColor(.bodyTextColor)
                .font(
                    .oswald(
                        .extraLight,
                        size: canShowBackground ? 20 : 30,
                        relativeTo: .title3
                    )
                )
                .baselineOffset(10)
                .frame(alignment: .topLeading)
                .minimumScaleFactor(0.8)

                Spacer()
            }

            let measurementShortName = viewModel.measurementShortName(from: entry.config)
            if !measurementShortName.isEmpty {
                Text(measurementShortName)
                    .foregroundColor(Color.sensorNameColor1)
                    .font(
                        .mulish(
                            .regular,
                            size: canShowBackground ? 12 : 16,
                            relativeTo: .body
                        )
                    )
                    .frame(maxWidth: .infinity, alignment: .bottomLeading)
                    .minimumScaleFactor(0.8)
            }

            measurementTimeView(for: entry)
        }
    }

    private var airQualityContent: some View {
        let display = viewModel.airQualityDisplay(
            from: entry.record,
            config: entry.config
        )
        let value = display.state == .undefined(0)
            ? RuuviLocalization.na
            : viewModel.getValue(
                from: entry.record,
                settings: entry.settings,
                config: entry.config
            )

        return VStack(alignment: .leading, spacing: 2) {
            SimpleWidgetAQIProminentView(
                value: value,
                superscriptValue: "/\(display.maxScore)",
                subscriptValue: viewModel.measurementShortName(from: entry.config),
                canShowBackground: canShowBackground
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            SimpleWidgetAQILinearProgressView(
                progress: display.progress,
                tintColor: display.state.widgetColor
            )
            .frame(height: 16)
            .offset(x: -5.5)
            .padding(.top, -8)
            .padding(.trailing, 12)

            measurementTimeView(for: entry)
        }
    }

    @ViewBuilder
    private func measurementTimeView(for entry: WidgetEntry) -> some View {
        Text(viewModel.measurementTime(from: entry))
            .foregroundColor(Color.sensorNameColor1)
            .font(
                .mulish(
                    .regular,
                    size: canShowBackground ? 12 : 16,
                    relativeTo: .body
                )
            )
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SimpleWidgetAQIProminentView: View {
    let value: String
    let superscriptValue: String
    let subscriptValue: String
    let canShowBackground: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(value)
                .foregroundColor(.bodyTextColor)
                .font(.oswald(.bold, size: canShowBackground ? 40 : 76, relativeTo: .largeTitle))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            VStack(alignment: .leading, spacing: 0) {
                Text(superscriptValue)
                    .foregroundColor(.bodyTextColor)
                    .font(
                        .oswald(
                            .extraLight,
                            size: canShowBackground ? 15 : 22,
                            relativeTo: .title3
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(subscriptValue)
                    .foregroundColor(.sensorNameColor1)
                    .font(
                        .mulish(
                            .regular,
                            size: canShowBackground ? 13 : 16,
                            relativeTo: .body
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.top, 2)

            Spacer(minLength: 8)
        }
    }
}

private struct SimpleWidgetAQILinearProgressView: View {
    let progress: CGFloat
    let tintColor: Color

    private enum Constants {
        static let padding: CGFloat = 5.5
        static let mainGlowSize: CGFloat = 11
        static let outerGlowSize: CGFloat = 16
        static let progressBarCornerRadius: CGFloat = 4
        static let minimumVisibleProgress: CGFloat = 0.05
    }

    var body: some View {
        GeometryReader { proxy in
            let progressBarRect = progressBarRect(in: proxy.size)
            let clampedProgress = min(max(progress, 0), 1)
            let adjustedProgress = clampedProgress == 0
                ? Constants.minimumVisibleProgress
                : clampedProgress
            let tipRadius = min(progressBarRect.height / 2, 10)
            let tipCenter = CGPoint(
                x: progressBarRect.minX + progressBarRect.width * adjustedProgress - tipRadius,
                y: progressBarRect.midY
            )

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: min(Constants.progressBarCornerRadius, progressBarRect.height / 2))
                    .fill(RuuviColor.ruuviAQILinePlaceholderColor.swiftUIColor)
                    .frame(width: progressBarRect.width, height: progressBarRect.height)
                    .position(x: progressBarRect.midX, y: progressBarRect.midY)

                RoundedRectangle(cornerRadius: min(Constants.progressBarCornerRadius, progressBarRect.height / 2))
                    .fill(tintColor)
                    .frame(width: max(0, progressBarRect.width * clampedProgress), height: progressBarRect.height)
                    .position(
                        x: progressBarRect.minX + max(0, progressBarRect.width * clampedProgress) / 2,
                        y: progressBarRect.midY
                    )

                dashboardTipGlow(tipRadius: tipRadius)
                    .position(tipCenter)

                Circle()
                    .fill(tintColor)
                    .frame(width: tipRadius * 2, height: tipRadius * 2)
                    .position(tipCenter)
            }
        }
    }

    private func progressBarRect(in size: CGSize) -> CGRect {
        let insetRect = CGRect(origin: .zero, size: size)
            .insetBy(dx: Constants.padding, dy: Constants.padding)

        guard insetRect.width > 0, insetRect.height > 0 else {
            let minPadding = min(Constants.padding, size.width / 4, size.height / 4)
            return CGRect(origin: .zero, size: size)
                .insetBy(dx: minPadding, dy: minPadding)
        }

        return insetRect
    }

    // swiftlint:disable:next function_body_length
    private func dashboardTipGlow(tipRadius: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tintColor.opacity(0.6),
                            tintColor.opacity(0.4),
                            tintColor.opacity(0.2),
                            tintColor.opacity(0.1),
                            tintColor.opacity(0.05),
                            tintColor.opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: Constants.outerGlowSize / 2
                    )
                )
                .frame(width: Constants.outerGlowSize, height: Constants.outerGlowSize)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tintColor,
                            tintColor.opacity(0.9),
                            tintColor.opacity(0.7),
                            tintColor.opacity(0.4),
                            tintColor.opacity(0.2),
                            tintColor.opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: Constants.mainGlowSize * 0.75
                    )
                )
                .frame(width: Constants.mainGlowSize * 1.5, height: Constants.mainGlowSize * 1.5)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tintColor,
                            tintColor.opacity(0.9),
                            tintColor.opacity(0.8),
                            tintColor.opacity(0.4),
                            tintColor.opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: tipRadius * 1.5
                    )
                )
                .frame(width: tipRadius * 3, height: tipRadius * 3)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            tintColor,
                            tintColor.opacity(0.8),
                            tintColor,
                            tintColor.opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: tipRadius * 1.25
                    )
                )
                .frame(width: tipRadius * 2.5, height: tipRadius * 2.5)
                .blendMode(.plusLighter)
        }
        .frame(width: Constants.outerGlowSize, height: Constants.outerGlowSize)
    }
}

private extension MeasurementQualityState {
    var widgetColor: Color {
        switch self {
        case .excellent:
            return RuuviColor.ruuviMeasurementExcellent.swiftUIColor
        case .good:
            return RuuviColor.ruuviMeasurementGood.swiftUIColor
        case .fair:
            return RuuviColor.ruuviMeasurementFair.swiftUIColor
        case .poor,
             .veryPoor:
            return RuuviColor.ruuviMeasurementPoor.swiftUIColor
        case .undefined:
            return RuuviColor.ruuviAQILinePlaceholderColor.swiftUIColor
        }
    }
}

extension EnvironmentValues {
    var canShowWidgetContainerBackground: Bool {
        if #available(iOSApplicationExtension 16.0, *) {
            self.showsWidgetContainerBackground
        } else {
            false
        }
    }

    var isFullColorWidgetRenderingMode: Bool {
        if #available(iOSApplicationExtension 16.0, *) {
            self.widgetRenderingMode == .fullColor
        } else {
            true
        }
    }
}
