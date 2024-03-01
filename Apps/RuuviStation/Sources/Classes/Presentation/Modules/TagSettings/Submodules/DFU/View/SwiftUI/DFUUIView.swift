import RuuviFirmware
import RuuviLocalization
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
        let errorTitle = RuuviLocalization.ErrorPresenterAlert.error
        let dbMigrationErrorTitle = RuuviLocalization.DFUUIView.DBMigration.Error.message
        let finish = RuuviLocalization.DfuFlash.Finish.text
    }

    private let muliBold16 = Font(UIFont.Muli(.bold, size: 16))
    private let muliRegular16 = Font(UIFont.Muli(.regular, size: 16))
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
                }.padding(
                    .top, 48
                )
            }
            .background(RuuviColor.primary.swiftUIColor)
            .edgesIgnoringSafeArea(.all)
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
    }

    private var content: some View {
        switch viewModel.state {
        case .idle:
            return Color.clear.eraseToAnyView()
        case .loading:
            return VStack(alignment: .leading, spacing: 16) {
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
            return Text(error.localizedDescription)
                .font(muliRegular16)
                .eraseToAnyView()
        case let .loaded(latestRelease):
            return VStack(alignment: .leading, spacing: 16) {
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
            return VStack(alignment: .leading, spacing: 16) {
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
            return VStack(alignment: .leading, spacing: 16) {
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
        case let .noNeedToUpgrade(_, currentRelease):
            return Text(texts.alreadyOnLatest)
                .font(muliRegular16)
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .padding()
                .onAppear { viewModel.storeCurrentFirmwareVersion(from: currentRelease) }
                .eraseToAnyView()
        case let .isAbleToUpgrade(latestRelease, currentRelease):
            return VStack {
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
        case .reading:
            return VStack {
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }.eraseToAnyView()
        case .downloading:
            return VStack(alignment: .center, spacing: 16) {
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
            return VStack {
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
            return VStack {
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
            return VStack(alignment: .center, spacing: 24) {
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
            return Text(texts.updatingTitle)
                .font(muliRegular16)
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .padding()
                .eraseToAnyView()
        case .servingAfterUpdate:
            return Text(texts.updatingTitle)
                .font(muliRegular16)
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .padding()
                .eraseToAnyView()
        case let .firmwareAfterUpdate(currentRelease):
            viewModel.storeUpdatedFirmware(currentRelease: currentRelease)
            return VStack {
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
            .padding()
            .eraseToAnyView()
        }
    }

    func goBack() {
        presentationMode.wrappedValue.dismiss()
    }
}
