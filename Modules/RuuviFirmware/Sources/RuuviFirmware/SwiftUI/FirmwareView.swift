// swiftlint:disable file_length
import RuuviLocalization
import SwiftUI

// swiftlint:disable:next type_body_length
struct FirmwareView: View {
    @ObservedObject var viewModel: FirmwareViewModel

    private struct Texts {
        let navigationTitle = "DFUUIView.navigationTitle".localized(for: FirmwareViewModel.self)
        let latestTitle = "DFUUIView.latestTitle".localized(for: FirmwareViewModel.self)
        let currentTitle = "DFUUIView.currentTitle".localized(for: FirmwareViewModel.self)
        let lowBatteryWarningMessage = "DFUUIView.lowBattery.warning.message".localized(for: FirmwareViewModel.self)
        let okTitle = "ErrorPresenterAlert.OK".localized(for: FirmwareViewModel.self)
        let notReportingDescription = "DFUUIView.notReportingDescription".localized(for: FirmwareViewModel.self)
        let alreadyOnLatest = "DFUUIView.alreadyOnLatest".localized(for: FirmwareViewModel.self)
        let startUpdateProcess = "DFUUIView.startUpdateProcess".localized(for: FirmwareViewModel.self)
        let downloadingTitle = "DFUUIView.downloadingTitle".localized(for: FirmwareViewModel.self)
        let prepareTitle = "DFUUIView.prepareTitle".localized(for: FirmwareViewModel.self)
        let openCoverTitle = "DFUUIView.openCoverTitle".localized(for: FirmwareViewModel.self)
        let localBootButtonTitle = "DFUUIView.locateBootButtonTitle".localized(for: FirmwareViewModel.self)
        let setUpdatingModeTitle = "DFUUIView.setUpdatingModeTitle".localized(for: FirmwareViewModel.self)
        let toBootModeTwoButtonsDescription = "DFUUIView.toBootModeTwoButtonsDescription".localized(
            for: FirmwareViewModel.self
        )
        let toBootModeOneButtonDescription = "DFUUIView.toBootModeOneButtonDescription".localized(
            for: FirmwareViewModel.self
        )
        let toBootModeSuccessTitle = "DFUUIView.toBootModeSuccessTitle".localized(for: FirmwareViewModel.self)
        let updatingTitle = "DFUUIView.updatingTitle".localized(for: FirmwareViewModel.self)
        let searchingTitle = "DFUUIView.searchingTitle".localized(for: FirmwareViewModel.self)
        let startTitle = "DFUUIView.startTitle".localized(for: FirmwareViewModel.self)
        let doNotCloseTitle = "DFUUIView.doNotCloseTitle".localized(for: FirmwareViewModel.self)
        let successfulTitle = "DFUUIView.successfulTitle".localized(for: FirmwareViewModel.self)
        let finish = "DfuFlash.Finish.text".localized(for: FirmwareViewModel.self)
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
        .accentColor(.red)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.send(event: .onAppear)
        }
    }
}

private extension CGFloat {
    func adjustedFontSize() -> CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? self + 4 : self
    }
}

// swiftlint:enable file_length
