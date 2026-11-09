// swiftlint:disable file_length
import RuuviLocalization
import SwiftUI

// swiftlint:disable:next type_body_length
struct FirmwareView: View {
    @ObservedObject var viewModel: FirmwareViewModel

    private struct Texts {
        let navigationTitle = RuuviLocalization.DFUUIView.navigationTitle
        let latestTitle = RuuviLocalization.DFUUIView.latestTitle
        let currentTitle = RuuviLocalization.DFUUIView.currentTitle
        let lowBatteryWarningMessage = RuuviLocalization.DFUUIView.LowBattery.Warning.message
        let okTitle = RuuviLocalization.ErrorPresenterAlert.ok
        let notReportingDescription = RuuviLocalization.DFUUIView.notReportingDescription
        let alreadyOnLatest = RuuviLocalization.DFUUIView.alreadyOnLatest
        let startUpdateProcess = RuuviLocalization.DFUUIView.startUpdateProcess
        let downloadingTitle = RuuviLocalization.DFUUIView.downloadingTitle
        let updatingTitle = RuuviLocalization.DFUUIView.updatingTitle
        let searchingTitle = RuuviLocalization.DFUUIView.searchingTitle
        let startTitle = RuuviLocalization.DFUUIView.startTitle
        let doNotCloseTitle = RuuviLocalization.DFUUIView.doNotCloseTitle
        let successfulTitle = RuuviLocalization.updateSuccessfulTag
        let finish = RuuviLocalization.DfuFlash.Finish.text
    }

    private let texts = Texts()
    private let titleFont = Font(RuuviFonts.mulish(.bold, size: 16))
    private let bodyFont = Font(RuuviFonts.mulish(.regular, size: 16))

    private var content: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.eraseToAnyView()
        case .loading:
            VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                    .font(titleFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .eraseToAnyView()
        case let .error(error):
            Text(error.localizedDescription)
                .font(bodyFont)
                .eraseToAnyView()
        case let .loaded(latestRelease):
            VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                    .font(titleFont)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                Text(latestRelease.version)
                    .font(bodyFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                Text(texts.currentTitle).bold()
                    .font(titleFont)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .onAppear { viewModel.send(event: .onLoaded(latestRelease)) }
            .eraseToAnyView()
        case let .serving(latestRelease):
            VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                    .font(titleFont)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                Text(latestRelease.version)
                    .font(bodyFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                Text(texts.currentTitle).bold()
                    .font(titleFont)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .eraseToAnyView()
        case let .checking(latestRelease, currentRelease):
            VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                    .font(titleFont)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                Text(latestRelease.version)
                    .font(bodyFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                Text(texts.currentTitle).bold()
                    .font(titleFont)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                if let currentVersion = currentRelease?.version {
                    Text(currentVersion)
                        .font(bodyFont)
                        .foregroundColor(RuuviColor.textColor.swiftUIColor)
                } else {
                    Text(texts.notReportingDescription)
                        .font(bodyFont)
                        .foregroundColor(RuuviColor.textColor.swiftUIColor)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .onAppear { viewModel.send(event: .onLoadedAndServed(latestRelease, currentRelease)) }
            .eraseToAnyView()
        case .noNeedToUpgrade:
            VStack {
                Text(texts.alreadyOnLatest)
                    .font(bodyFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .padding()
                Button(
                    action: {
                        viewModel.finish()
                    },
                    label: {
                        Text(texts.finish)
                            .font(titleFont)
                            .frame(maxWidth: .infinity)
                    }
                )
                .buttonStyle(
                    LargeButtonStyle(
                        backgroundColor: RuuviColor.tintColor.swiftUIColor,
                        foregroundColor: Color.white,
                        isDisabled: false
                    )
                )
                .padding()
                .frame(maxWidth: .infinity)
            }
            .eraseToAnyView()
        case let .isAbleToUpgrade(latestRelease, currentRelease):
            VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text(texts.latestTitle).bold()
                        .font(titleFont)
                        .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                    Text(latestRelease.version)
                        .font(bodyFont)
                        .foregroundColor(RuuviColor.textColor.swiftUIColor)
                    Text(texts.currentTitle).bold()
                        .font(titleFont)
                        .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                    if let currentVersion = currentRelease?.version {
                        Text(currentVersion)
                            .font(bodyFont)
                            .foregroundColor(RuuviColor.textColor.swiftUIColor)
                    } else {
                        Text(texts.notReportingDescription)
                            .font(bodyFont)
                            .foregroundColor(RuuviColor.textColor.swiftUIColor)
                    }
                    Button(
                        action: {
                            viewModel.send(
                                event: .onStartUpgrade(latestRelease, currentRelease)
                            )
                        },
                        label: {
                            HStack {
                                Text(texts.startUpdateProcess)
                                    .font(titleFont)
                            }.frame(maxWidth: .infinity)
                        }
                    )
                    .buttonStyle(
                        LargeButtonStyle(
                            backgroundColor: RuuviColor.tintColor.swiftUIColor,
                            foregroundColor: Color.white,
                            isDisabled: false
                        )
                    )
                    .padding()
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .eraseToAnyView()
        case .downloading:
            VStack(alignment: .center, spacing: 16) {
                Text(texts.downloadingTitle)
                    .font(bodyFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                ProgressBar(value: $viewModel.downloadProgress)
                    .frame(height: 16)
                    .padding()
                Text("\(Int(viewModel.downloadProgress * 100))%")
                    .font(bodyFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .eraseToAnyView()
        case .listening:
            VStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        RuuviBoardView()
                        DFUInstructionsView()
                        Button(
                            action: {},
                            label: {
                                HStack {
                                    Text(texts.searchingTitle)
                                        .font(titleFont)
                                        .foregroundColor(.secondary)
                                    Spinner(isAnimating: true, style: .medium).eraseToAnyView()
                                }.frame(maxWidth: .infinity)
                            }
                        )
                        .buttonStyle(
                            LargeButtonStyle(
                                backgroundColor: RuuviColor.tintColor.swiftUIColor,
                                foregroundColor: Color.white,
                                isDisabled: true
                            )
                        )
                        .padding()
                        .disabled(true)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
            .padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
            .eraseToAnyView()
        case let .readyToUpdate(latestRelease, currentRelease, uuid, appUrl, fullUrl):
            VStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        RuuviBoardView()
                        DFUInstructionsView()
                        Button(
                            action: {
                                viewModel.send(
                                    event: .onUserDidConfirmToFlash(
                                        latestRelease,
                                        currentRelease,
                                        uuid: uuid,
                                        appUrl: appUrl,
                                        fullUrl: fullUrl
                                    )
                                )
                            },
                            label: {
                                Text(texts.startTitle)
                                    .font(titleFont)
                                    .frame(maxWidth: .infinity)
                            }
                        )
                        .buttonStyle(
                            LargeButtonStyle(
                                backgroundColor: RuuviColor.tintColor.swiftUIColor,
                                foregroundColor: Color.white,
                                isDisabled: false
                            )
                        )
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
            .padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
            .onAppear {
                viewModel.ensureBatteryHasEnoughPower(uuid: uuid)
            }
            .eraseToAnyView()
        case .flashing:
            VStack(alignment: .center, spacing: 24) {
                Text(texts.updatingTitle)
                    .font(bodyFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                ProgressBar(value: $viewModel.flashProgress)
                    .frame(height: 16)
                Text("\(Int(viewModel.flashProgress * 100))%")
                    .font(bodyFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                Text(texts.doNotCloseTitle)
                    .font(titleFont)
                    .bold()
                    .multilineTextAlignment(.center)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .eraseToAnyView()
        case .successfulyFlashed:
            VStack {
                Text(texts.successfulTitle)
                    .font(bodyFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                    .padding()
                Button(
                    action: {
                        viewModel.finish()
                    },
                    label: {
                        Text(texts.finish)
                            .font(titleFont)
                            .frame(maxWidth: .infinity)
                    }
                )
                .buttonStyle(
                    LargeButtonStyle(
                        backgroundColor: RuuviColor.tintColor.swiftUIColor,
                        foregroundColor: Color.white,
                        isDisabled: false
                    )
                )
                .padding()
                .frame(maxWidth: .infinity)
            }
            .eraseToAnyView()
        }
    }

    var body: some View {
        stateLayout
            .alert(isPresented: $viewModel.isBatteryLow) {
                Alert(
                    title: Text(""),
                    message: Text(texts.lowBatteryWarningMessage),
                    dismissButton: .cancel(Text(texts.okTitle))
                )
            }
            .padding()
            .accentColor(.red)
            .navigationBarBackButtonHidden(true)
            .onAppear {
                viewModel.send(event: .onAppear)
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                viewModel.restartPropertiesDaemon()
                UIApplication.shared.isIdleTimerDisabled = false
            }
    }

    /// How `content` fills the sheet.
    /// - `.listening` and `.readyToUpdate` scroll, so they take the whole height.
    /// - Every other state keeps its content in the upper part of the sheet, as it always has: a
    ///   flexible filler below the content takes up to half of the height.
    /// - The states with a button (and `.flashing`) scroll as a whole when they don't fit the height
    ///   at all (a short window), so the button stays reachable. Whenever they fit, as on every iPhone
    ///   and full-screen iPad, they look exactly as without the scroll view. None of these states has
    ///   an `onAppear`, which matters because `ViewThatFits` builds the content for both variants.
    @ViewBuilder
    private var stateLayout: some View {
        switch viewModel.state {
        case .listening, .readyToUpdate:
            content
        case .noNeedToUpgrade, .isAbleToUpgrade, .flashing, .successfulyFlashed:
            ViewThatFits(in: .vertical) {
                contentAboveFiller
                ScrollView(showsIndicators: false) {
                    content
                }
            }
        default:
            contentAboveFiller
        }
    }

    private var contentAboveFiller: some View {
        VStack {
            content
            // Flexible like the GeometryReader that used to measure the width here, so the VStack
            // splits the height exactly as before. The ideal height of 0 lets `ViewThatFits` compare
            // only the content with the available height.
            Color.clear
                .frame(idealHeight: 0)
        }
    }

    /// A multi-line label that wraps at the width SwiftUI actually gives it, on every layout pass, so
    /// the instructions reflow when the window is resized or rotated.
    private struct AttributedText: UIViewRepresentable {
        let attributedString: NSAttributedString

        func makeUIView(context: Context) -> UILabel {
            let label = UILabel()
            label.attributedText = attributedString
            label.numberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.textAlignment = .left

            label.setContentCompressionResistancePriority(.required, for: .vertical)
            label.setContentHuggingPriority(.required, for: .vertical)
            label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)

            return label
        }

        func updateUIView(_: UILabel, context _: Context) {}

        func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context _: Context) -> CGSize? {
            guard let width = proposal.width, width > 0, width.isFinite else { return nil }
            let fitting = uiView.sizeThatFits(
                CGSize(width: width, height: .greatestFiniteMagnitude)
            )
            return CGSize(width: width, height: ceil(fitting.height))
        }
    }

    struct DFUInstructionsView: View {
        var body: some View {
            AttributedText(
                attributedString: NSAttributedString.fromFormattedDescription(
                    RuuviLocalization.prepareYourSensorInstructions,
                    titleFont: UIFont.ruuviHeadline(),
                    paragraphFont: UIFont.ruuviBody(),
                    boldFont: UIFont.ruuviHeadline(),
                    titleColor: RuuviColor.menuTextColor.color,
                    paragraphColor: RuuviColor.textColor.color,
                    linkColor: RuuviColor.tintColor.color,
                    linkFont: .ruuviCallout()
                )
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// swiftlint:enable file_length
