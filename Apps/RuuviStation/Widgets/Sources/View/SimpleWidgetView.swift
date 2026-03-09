import RuuviLocalization
import RuuviOntology
import SwiftUI
import WidgetKit

struct SimpleWidgetView: View {
    @Environment(\.canShowWidgetContainerBackground) private var canShowBackground
    private let viewModel = WidgetViewModel()
    var entry: WidgetEntry
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

                    let measurementShortName = viewModel.measurementShortName(from: entry.config)
                    if !measurementShortName.isEmpty {
                        Text(measurementShortName)
                            .foregroundColor(Color.sensorNameColor1)
                            .font(
                                .mulish(
                                    .regular,
                                    size: canShowBackground ? 10 : 14,
                                    relativeTo: .body
                                )
                            )
                            .frame(maxWidth: .infinity, alignment: .bottomLeading)
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
                                Button(intent: WidgetRefresher(target: .simple)
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
            }
            .widgetURL(
                viewModel.widgetDeepLinkURL(
                    sensorId: entry.tag.identifier,
                    record: entry.record
                )
            )
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
