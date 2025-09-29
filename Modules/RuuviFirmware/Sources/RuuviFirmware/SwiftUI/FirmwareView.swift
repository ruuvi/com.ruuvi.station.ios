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
        let successfulTitle = RuuviLocalization.DFUUIView.successfulTitle
        let finish = RuuviLocalization.DfuFlash.Finish.text
    }

    private let texts = Texts()
    private let titleFont = Font(RuuviFonts.mulish(.bold, size: 16))
    private let bodyFont = Font(RuuviFonts.mulish(.regular, size: 16))
    @State private var superviewSize: CGSize = .zero

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
                        DFUInstructionsView(maxWidth: superviewSize.width - 32)
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
                        DFUInstructionsView(maxWidth: superviewSize.width - 32)
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
        VStack {
            content
            GeometryReader { proxy in
                HStack {} // just an empty container to get superview size.
                    .onAppear {
                        superviewSize = proxy.size
                    }
            }
        }
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

    private struct AttributedText: UIViewRepresentable {
        let attributedString: NSAttributedString
        let maxWidth: CGFloat

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
            label.preferredMaxLayoutWidth = maxWidth

            return label
        }

        func updateUIView(_ uiView: UILabel, context: Context) {
            uiView.preferredMaxLayoutWidth = maxWidth
            uiView.invalidateIntrinsicContentSize()
            uiView.setNeedsLayout()
        }
    }

    struct DFUInstructionsView: View {
        let maxWidth: CGFloat
        var body: some View {
            AttributedText(
                attributedString: NSAttributedString.fromFormattedDescription(
                    RuuviLocalization.prepareYourSensorInstructions,
                    titleFont: UIFont.ruuviHeadline(),
                    paragraphFont: UIFont.ruuviBody(),
                    titleColor: RuuviColor.menuTextColor.color,
                    paragraphColor: RuuviColor.textColor.color,
                    linkColor: RuuviColor.tintColor.color,
                    linkFont: .ruuviCallout()
                ),
                maxWidth: maxWidth
            )
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension CGFloat {
    func adjustedFontSize() -> CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? self + 4 : self
    }
}

// swiftlint:enable file_length
