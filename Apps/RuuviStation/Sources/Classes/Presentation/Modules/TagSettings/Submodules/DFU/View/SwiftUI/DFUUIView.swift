import RuuviFirmware
import RuuviLocalization
import RuuviOntology
import SwiftUI

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
struct DFUUIView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @ObservedObject var viewModel: DFUViewModel

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
        let updateAirRebootWaiting = RuuviLocalization.updateAirRebootWaiting
        let searchingTitle = RuuviLocalization.DFUUIView.searchingTitle
        let startTitle = RuuviLocalization.DFUUIView.startTitle
        let doNotCloseTitle = RuuviLocalization.DFUUIView.doNotCloseTitle
        let successfulTitleTag = RuuviLocalization.updateSuccessfulTag
        let successfulTitleAir = RuuviLocalization.updateSuccessfulAir
        let errorAirTimeout = RuuviLocalization.updateAirCheckTimeout
        let errorAirVersionMismatch = RuuviLocalization.updateAirVersionMismatch
        let errorTitle = RuuviLocalization.ErrorPresenterAlert.error
        let dbMigrationErrorTitle = RuuviLocalization.DFUUIView.DBMigration.Error.message
        let finish = RuuviLocalization.DfuFlash.Finish.text
    }

    private let titleFont = Font(RuuviFonts.mulish(.bold, size: 16))
    private let bodyFont = Font(RuuviFonts.mulish(.regular, size: 16))
    private let texts = Texts()
    @State private var isBatteryLow = false

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    content
                        .alert(
                            isPresented: $viewModel.isMigrationFailed
                        ) {
                            Alert(
                                title: Text(
                                    texts.errorTitle
                                ),
                                message: Text(
                                    texts.dbMigrationErrorTitle
                                ),
                                dismissButton: .cancel(
                                    Text(
                                        texts.okTitle
                                    )
                                )
                            )
                        }
                }
                .padding(
                    .top, 48
                )
            }
            .background(RuuviColor.primary.swiftUIColor)
            .modifier(DFUSafeAreaModifier())
            .navigationBarTitle(texts.navigationTitle)
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button(action: goBack) {
                HStack {
                    RuuviAsset.dismissModalIcon.swiftUIImage
                        .foregroundColor(.primary)
                }
            })
            .onAppear {
                viewModel.send(event: .onAppear)
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                viewModel.restartPropertiesDaemon()
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var content: some View {
        switch viewModel.state {
        case .idle:
            return Color.clear.eraseToAnyView()
        case .loading:
            return VStack(alignment: .leading, spacing: 16) {
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
            return ZStack {
                Color.clear
                Text(errorText(for: error))
                    .font(bodyFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
            }.eraseToAnyView()
        case let .loaded(latestRelease):
            return VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                    .font(titleFont)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                Text(latestRelease.version.ruuviFirmwareDisplayValue)
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
            return VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                    .font(titleFont)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                Text(latestRelease.version.ruuviFirmwareDisplayValue)
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
            return VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                    .font(titleFont)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                Text(latestRelease.version.ruuviFirmwareDisplayValue)
                    .font(bodyFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                if currentRelease == nil {
                    Text(texts.searchingTitle)
                        .font(bodyFont)
                        .foregroundColor(RuuviColor.textColor.swiftUIColor)
                    Spinner(isAnimating: true, style: .medium).eraseToAnyView()
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
        case let .noNeedToUpgrade(latestRelease, currentRelease):
            return VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                    .font(titleFont)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                Text(latestRelease.version.ruuviFirmwareDisplayValue)
                    .font(bodyFont)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                Text(texts.alreadyOnLatest)
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
        case let .isAbleToUpgrade(latestRelease, currentRelease):
            return DFUScrollableIfNeeded {
                VStack(alignment: .leading, spacing: 16) {
                    Text(texts.latestTitle).bold()
                        .font(titleFont)
                        .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                    Text(latestRelease.version.ruuviFirmwareDisplayValue)
                        .font(bodyFont)
                        .foregroundColor(RuuviColor.textColor.swiftUIColor)
                    Text(texts.currentTitle).bold()
                        .font(titleFont)
                        .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                    if let currentVersion = currentRelease?.version {
                        Text(currentVersion.ruuviFirmwareDisplayValue)
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
            .onAppear(perform: {
                viewModel.checkBatteryState(completion: { isLow in
                    isBatteryLow = isLow
                })
            })
            .alert(isPresented: $isBatteryLow) {
                Alert(
                    title: Text(""),
                    message: Text(texts.lowBatteryWarningMessage),
                    dismissButton: .cancel(Text(texts.okTitle))
                )
            }
            .padding()
            .eraseToAnyView()
        case .downloading:
            return VStack(alignment: .center, spacing: 16) {
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
            return VStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if !viewModel.isRuuviAir() {
                            RuuviBoardView()
                        }
                        DFUInstructionsView(isAir: viewModel.isRuuviAir())
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
        case let .readyToUpdate(latestRelease, currentRelease, dfuDevice, appUrl, fullUrl, additionalFiles):
            return VStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if !viewModel.isRuuviAir() {
                            RuuviBoardView()
                        }
                        DFUInstructionsView(isAir: viewModel.isRuuviAir())
                        Button(
                            action: {
                                viewModel.send(
                                    event: .onUserDidConfirmToFlash(
                                        latestRelease,
                                        currentRelease,
                                        dfuDevice: dfuDevice,
                                        appUrl: appUrl,
                                        fullUrl: fullUrl,
                                        additionalFiles: additionalFiles
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
            .eraseToAnyView()
        case .flashing:
            return DFUScrollableIfNeeded {
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
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .eraseToAnyView()
        case .successfulyFlashed:
            return waitForFlashingView()
        case .servingAfterUpdate:
            return waitForFlashingView()
        case let .firmwareAfterUpdate(latestRelease, currentRelease):
            viewModel
                .storeUpdatedFirmware(
                    latestRelease: latestRelease,
                    currentRelease: currentRelease
                )
            return VStack {
                Text(viewModel.isRuuviAir() ?
                     texts.successfulTitleAir : texts.successfulTitleTag)
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
            .padding()
            .eraseToAnyView()
        }
    }

    private func waitForFlashingView() -> AnyView {
        Text(viewModel.isRuuviAir() ?
             texts.updateAirRebootWaiting : texts.updatingTitle)
            .font(bodyFont)
            .foregroundColor(RuuviColor.textColor.swiftUIColor)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .eraseToAnyView()
    }

    private func errorText(for error: Error) -> String {
        guard viewModel.isRuuviAir(),
              let dfuError = error as? DFUError else {
            return error.localizedDescription
        }

        switch dfuError {
        case .airDeviceTimeout:
            return texts.errorAirTimeout
        case .airVersionMismatch:
            return texts.errorAirVersionMismatch
        default:
            return error.localizedDescription
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
        let isAir: Bool
        var body: some View {
            AttributedText(
                attributedString: NSAttributedString.fromFormattedDescription(
                    isAir ? RuuviLocalization.dfuAirUpdateInstructions :
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

    func goBack() {
        presentationMode.wrappedValue.dismiss()
    }
}

/// `content` as it is when it fits the height it is given, and in a scroll view when it doesn't (a
/// short window), so a state's button stays reachable. Whenever the content fits, as on every
/// iPhone and full-screen iPad, this is exactly `content`.
///
/// Keep side effects (`onAppear`, alerts) outside: the content is measured in both variants.
private struct DFUScrollableIfNeeded<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView(showsIndicators: false) {
                content
            }
        }
    }
}

/// `edgesIgnoringSafeArea(.all)`, except while iPhone Duo shows its vertical bar on a side of the
/// display: then the content keeps the side safe area (so it doesn't run under the bar) and only
/// the background extends there. On iPhone and iPad this is exactly `edgesIgnoringSafeArea(.all)`.
private struct DFUSafeAreaModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(DFUVerticalBarSafeAreaModifier())
        } else {
            content.edgesIgnoringSafeArea(.all)
        }
    }
}

@available(iOS 27.1, *)
private struct DFUVerticalBarSafeAreaModifier: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var verticalBarEdge

    // One view structure for both states, so the view keeps its identity (and state) when the
    // vertical bar comes and goes.
    func body(content: Content) -> some View {
        let hasVerticalBar = verticalBarEdge != nil
        content
            .edgesIgnoringSafeArea(hasVerticalBar ? [.top, .bottom] : .all)
            .background(
                (hasVerticalBar ? RuuviColor.primary.swiftUIColor : Color.clear)
                    .edgesIgnoringSafeArea(.all)
            )
    }
}
