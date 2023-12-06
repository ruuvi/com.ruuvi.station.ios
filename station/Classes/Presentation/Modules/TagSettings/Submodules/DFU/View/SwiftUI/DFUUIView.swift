import RuuviFirmware
import SwiftUI

// swiftlint:disable file_length
// swiftlint:disable:next type_body_length
struct DFUUIView: View {
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @ObservedObject var viewModel: DFUViewModel

    private struct Texts {
        let navigationTitle = "DFUUIView.navigationTitle".localized()
        let latestTitle = "DFUUIView.latestTitle".localized()
        let currentTitle = "DFUUIView.currentTitle".localized()
        let lowBatteryWarningMessage = "DFUUIView.lowBattery.warning.message".localized()
        let okTitle = "ErrorPresenterAlert.OK".localized()
        let notReportingDescription = "DFUUIView.notReportingDescription".localized()
        let alreadyOnLatest = "DFUUIView.alreadyOnLatest".localized()
        let startUpdateProcess = "DFUUIView.startUpdateProcess".localized()
        let downloadingTitle = "DFUUIView.downloadingTitle".localized()
        let prepareTitle = "DFUUIView.prepareTitle".localized()
        let openCoverTitle = "DFUUIView.openCoverTitle".localized()
        let localBootButtonTitle = "DFUUIView.locateBootButtonTitle".localized()
        let setUpdatingModeTitle = "DFUUIView.setUpdatingModeTitle".localized()
        let toBootModeTwoButtonsDescription = "DFUUIView.toBootModeTwoButtonsDescription".localized()
        let toBootModeOneButtonDescription = "DFUUIView.toBootModeOneButtonDescription".localized()
        let toBootModeSuccessTitle = "DFUUIView.toBootModeSuccessTitle".localized()
        let updatingTitle = "DFUUIView.updatingTitle".localized()
        let searchingTitle = "DFUUIView.searchingTitle".localized()
        let startTitle = "DFUUIView.startTitle".localized()
        let doNotCloseTitle = "DFUUIView.doNotCloseTitle".localized()
        let successfulTitle = "DFUUIView.successfulTitle".localized()
        let errorTitle = "ErrorPresenterAlert.Error".localized()
        let dbMigrationErrorTitle = "DFUUIView.DBMigration.Error.message".localized()
    }

    private let muliBold16 = Font(UIFont.Muli(.bold, size: 16))
    private let muliRegular16 = Font(UIFont.Muli(.regular, size: 16))
    private let texts = Texts()
    @State private var isBatteryLow = false

    var body: some View {
        VStack {
            content
                .alert(isPresented: $viewModel.isMigrationFailed) {
                    Alert(title: Text(texts.errorTitle),
                          message: Text(texts.dbMigrationErrorTitle),
                          dismissButton: .cancel(Text(texts.okTitle)))
                }
        }
        .background(Color(RuuviColor.ruuviPrimarySUI!).edgesIgnoringSafeArea(.all))
        .navigationBarTitle(
            texts.navigationTitle
        )
        .accentColor(.red)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: Button(action: goBack) {
            HStack {
                Image("chevron_back")
                    .foregroundColor(.primary)
            }
        })
        .onAppear {
            self.viewModel.send(event: .onAppear)
        }
        .onDisappear {
            self.viewModel.restartPropertiesDaemon()
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
                    .foregroundColor(RuuviColor.ruuviTextColorSUI)
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .eraseToAnyView()
        case .error(let error):
            return Text(error.localizedDescription)
                .font(muliRegular16)
                .eraseToAnyView()
        case let .loaded(latestRelease):
            return VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                    .font(muliBold16)
                    .foregroundColor(RuuviColor.ruuviTitleTextColorSUI)
                Text(latestRelease.version)
                    .font(muliRegular16)
                    .foregroundColor(RuuviColor.ruuviTextColorSUI)
                Text(texts.currentTitle).bold()
                    .font(muliBold16)
                    .foregroundColor(RuuviColor.ruuviTitleTextColorSUI)
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .onAppear { self.viewModel.send(event: .onLoaded(latestRelease)) }
            .eraseToAnyView()
        case let .serving(latestRelease):
            return VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                    .font(muliBold16)
                    .foregroundColor(RuuviColor.ruuviTitleTextColorSUI)
                Text(latestRelease.version)
                    .font(muliRegular16)
                    .foregroundColor(RuuviColor.ruuviTextColorSUI)
                Text(texts.currentTitle).bold()
                    .font(muliBold16)
                    .foregroundColor(RuuviColor.ruuviTitleTextColorSUI)
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
                    .foregroundColor(RuuviColor.ruuviTitleTextColorSUI)
                Text(latestRelease.version)
                    .font(muliRegular16)
                    .foregroundColor(RuuviColor.ruuviTextColorSUI)
                Text(texts.currentTitle).bold()
                    .font(muliBold16)
                    .foregroundColor(RuuviColor.ruuviTitleTextColorSUI)
                if let currentVersion = currentRelease?.version {
                    Text(currentVersion)
                        .font(muliRegular16)
                        .foregroundColor(RuuviColor.ruuviTextColorSUI)
                } else {
                    Text(texts.notReportingDescription)
                        .font(muliRegular16)
                        .foregroundColor(RuuviColor.ruuviTextColorSUI)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .onAppear { self.viewModel.send(event: .onLoadedAndServed(latestRelease, currentRelease)) }
            .eraseToAnyView()
        case .noNeedToUpgrade(_, let currentRelease):
            return Text(texts.alreadyOnLatest)
                .font(muliRegular16)
                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .padding()
                .onAppear { self.viewModel.storeCurrentFirmwareVersion(from: currentRelease) }
                .eraseToAnyView()
        case let .isAbleToUpgrade(latestRelease, currentRelease):
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text(texts.latestTitle).bold()
                        .font(muliBold16)
                        .foregroundColor(RuuviColor.ruuviTitleTextColorSUI)
                    Text(latestRelease.version)
                        .font(muliRegular16)
                        .foregroundColor(RuuviColor.ruuviTextColorSUI)
                    Text(texts.currentTitle).bold()
                        .font(muliBold16)
                        .foregroundColor(RuuviColor.ruuviTitleTextColorSUI)
                    if let currentVersion = currentRelease?.version {
                        Text(currentVersion)
                            .font(muliRegular16)
                            .foregroundColor(RuuviColor.ruuviTextColorSUI)
                    } else {
                        Text(texts.notReportingDescription)
                            .font(muliRegular16)
                            .foregroundColor(RuuviColor.ruuviTextColorSUI)
                    }
                    Button(
                        action: {
                            self.viewModel.send(
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
                            backgroundColor: RuuviColor.ruuviTintColorSUI,
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
                Alert(title: Text(""),
                      message: Text(texts.lowBatteryWarningMessage),
                      dismissButton: .cancel(Text(texts.okTitle)))
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
                    .foregroundColor(RuuviColor.ruuviTextColorSUI)
                ProgressBar(value: $viewModel.downloadProgress)
                    .frame(height: 16)
                    .padding()
                Text("\(Int(viewModel.downloadProgress * 100))%")
                    .font(muliRegular16)
                    .foregroundColor(RuuviColor.ruuviTextColorSUI)
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
                                .foregroundColor(RuuviColor.ruuviTitleTextColorSUI)
                            Text(texts.openCoverTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                            Text(texts.localBootButtonTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                            Text(texts.setUpdatingModeTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                            Text(texts.toBootModeTwoButtonsDescription)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                            Text(texts.toBootModeOneButtonDescription)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                            Text(texts.toBootModeSuccessTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.ruuviTextColorSUI)
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
                                backgroundColor: RuuviColor.ruuviTintColorSUI,
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
                                .foregroundColor(RuuviColor.ruuviTitleTextColorSUI)
                            Text(texts.openCoverTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                            Text(texts.localBootButtonTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                            Text(texts.setUpdatingModeTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                            Text(texts.toBootModeTwoButtonsDescription)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                            Text(texts.toBootModeOneButtonDescription)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                            Text(texts.toBootModeSuccessTitle)
                                .font(muliRegular16)
                                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                        }
                        Button(
                            action: {
                                self.viewModel.send(
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
                                backgroundColor: RuuviColor.ruuviTintColorSUI,
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
                    .foregroundColor(RuuviColor.ruuviTextColorSUI)
                ProgressBar(value: $viewModel.flashProgress)
                    .frame(height: 16)
                Text("\(Int(viewModel.flashProgress * 100))%")
                    .font(muliRegular16)
                    .foregroundColor(RuuviColor.ruuviTextColorSUI)
                Text(texts.doNotCloseTitle)
                    .font(muliBold16)
                    .bold()
                    .multilineTextAlignment(.center)
                    .foregroundColor(RuuviColor.ruuviTextColorSUI)

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
                .foregroundColor(RuuviColor.ruuviTextColorSUI)
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
                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .padding()
                .eraseToAnyView()
        case .firmwareAfterUpdate(let currentRelease):
            viewModel.storeUpdatedFirmware(currentRelease: currentRelease)
            return Text(texts.successfulTitle)
                .font(muliRegular16)
                .foregroundColor(RuuviColor.ruuviTextColorSUI)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .padding()
                .eraseToAnyView()
        }
    }

    func goBack() {
        self.presentationMode.wrappedValue.dismiss()
    }
}
