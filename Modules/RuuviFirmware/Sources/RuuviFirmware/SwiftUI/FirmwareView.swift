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
        let prepareTitle = RuuviLocalization.DFUUIView.prepareTitle
        let openCoverTitle = RuuviLocalization.DFUUIView.openCoverTitle
        let localBootButtonTitle = RuuviLocalization.DFUUIView.locateBootButtonTitle
        let setUpdatingModeTitle = RuuviLocalization.DFUUIView.setUpdatingModeTitle
        let toBootModeTwoButtonsDescription = RuuviLocalization.DFUUIView.toBootModeTwoButtonsDescription
        let toBootModeOneButtonDescription = RuuviLocalization.DFUUIView.toBootModeOneButtonDescription
        let toBootModeSuccessTitle = RuuviLocalization.DFUUIView.toBootModeSuccessTitle
        let updatingTitle = RuuviLocalization.DFUUIView.updatingTitle
        let searchingTitle = RuuviLocalization.DFUUIView.searchingTitle
        let startTitle = RuuviLocalization.DFUUIView.startTitle
        let doNotCloseTitle = RuuviLocalization.DFUUIView.doNotCloseTitle
        let successfulTitle = RuuviLocalization.DFUUIView.successfulTitle
        let finish = RuuviLocalization.DfuFlash.Finish.text
    }

    private let texts = Texts()
    private static let fontSize: CGFloat = 16
    private let muliBold16 = Font(
        UIFont(name: "Muli-Bold", size: fontSize.adjustedFontSize()) ??
            UIFont.systemFont(ofSize: fontSize.adjustedFontSize(), weight: .bold))
    private let muliRegular16 = Font(
        UIFont(name: "Muli-Regular", size: fontSize.adjustedFontSize()) ??
            UIFont.systemFont(ofSize: fontSize.adjustedFontSize(), weight: .regular))

    private var content: some View {
        switch viewModel.state {
        case .idle:
            Color.clear.eraseToAnyView()
        case .loading:
            VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                    .font(muliBold16)
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
                .font(muliRegular16)
                .eraseToAnyView()
        case let .loaded(latestRelease):
            VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                    .font(muliBold16)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                Text(latestRelease.version)
                    .font(muliRegular16)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                Text(texts.currentTitle).bold()
                    .font(muliBold16)
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
                    .font(muliBold16)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                Text(latestRelease.version)
                    .font(muliRegular16)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                Text(texts.currentTitle).bold()
                    .font(muliBold16)
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
                    .font(muliBold16)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                Text(latestRelease.version)
                    .font(muliRegular16)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                Text(texts.currentTitle).bold()
                    .font(muliBold16)
                    .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                if let currentVersion = currentRelease?.version {
                    Text(currentVersion)
                        .font(muliRegular16)
                        .foregroundColor(RuuviColor.textColor.swiftUIColor)
                } else {
                    Text(texts.notReportingDescription)
                        .font(muliRegular16)
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
                    .font(muliRegular16)
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
                            .font(muliBold16)
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
                        .font(muliBold16)
                        .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                    Text(latestRelease.version)
                        .font(muliRegular16)
                        .foregroundColor(RuuviColor.textColor.swiftUIColor)
                    Text(texts.currentTitle).bold()
                        .font(muliBold16)
                        .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                    if let currentVersion = currentRelease?.version {
                        Text(currentVersion)
                            .font(muliRegular16)
                            .foregroundColor(RuuviColor.textColor.swiftUIColor)
                    } else {
                        Text(texts.notReportingDescription)
                            .font(muliRegular16)
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
                                    .font(muliBold16)
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
        case .reading:
            VStack {
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }.eraseToAnyView()
        case .downloading:
            VStack(alignment: .center, spacing: 16) {
                Text(texts.downloadingTitle)
                    .font(muliRegular16)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                ProgressBar(value: $viewModel.downloadProgress)
                    .frame(height: 16)
                    .padding()
                Text("\(Int(viewModel.downloadProgress * 100))%")
                    .font(muliRegular16)
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
                        VStack(alignment: .leading, spacing: 16) {
                            Text(texts.prepareTitle).bold()
                                .font(muliBold16)
                                .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                            Text(texts.openCoverTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                            Text(texts.localBootButtonTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                            Text(texts.setUpdatingModeTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                            Text(texts.toBootModeTwoButtonsDescription)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                            Text(texts.toBootModeOneButtonDescription)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                            Text(texts.toBootModeSuccessTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                        }
                        Button(
                            action: {},
                            label: {
                                HStack {
                                    Text(texts.searchingTitle)
                                        .font(muliBold16)
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
                        VStack(alignment: .leading, spacing: 16) {
                            Text(texts.prepareTitle).bold()
                                .font(muliBold16)
                                .foregroundColor(RuuviColor.menuTextColor.swiftUIColor)
                            Text(texts.openCoverTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                            Text(texts.localBootButtonTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                            Text(texts.setUpdatingModeTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                            Text(texts.toBootModeTwoButtonsDescription)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                            Text(texts.toBootModeOneButtonDescription)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                            Text(texts.toBootModeSuccessTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                        }
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
                                    .font(muliBold16)
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
                    .font(muliRegular16)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                ProgressBar(value: $viewModel.flashProgress)
                    .frame(height: 16)
                Text("\(Int(viewModel.flashProgress * 100))%")
                    .font(muliRegular16)
                    .foregroundColor(RuuviColor.textColor.swiftUIColor)
                Text(texts.doNotCloseTitle)
                    .font(muliBold16)
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
                    .font(muliRegular16)
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
                            .font(muliBold16)
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
}

private extension CGFloat {
    func adjustedFontSize() -> CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? self + 4 : self
    }
}

// swiftlint:enable file_length
