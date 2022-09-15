import SwiftUI
import Localize_Swift

// swiftlint:disable:next type_body_length
struct DFUUIView: View {
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

    private let texts = Texts()
    @State private var isBatteryLow = false

    var body: some View {
        VStack {
            content
                .navigationBarTitle(
                    texts.navigationTitle
                )
                .alert(isPresented: $viewModel.isMigrationFailed) {
                    Alert(title: Text(texts.errorTitle),
                          message: Text(texts.dbMigrationErrorTitle),
                          dismissButton: .cancel(Text(texts.okTitle)))
                }
        }
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
            return Text(error.localizedDescription).eraseToAnyView()
        case let .loaded(latestRelease):
            return VStack(alignment: .leading, spacing: 16) {
                Text(texts.latestTitle).bold()
                Text(latestRelease.version)
                Text(texts.currentTitle).bold()
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
                Text(latestRelease.version)
                Text(texts.currentTitle).bold()
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
                Text(latestRelease.version)
                Text(texts.currentTitle).bold()
                if let currentVersion = currentRelease?.version {
                    Text(currentVersion)
                } else {
                    Text(texts.notReportingDescription)
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
        case .noNeedToUpgrade:
            return Text(texts.alreadyOnLatest)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .padding()
                .eraseToAnyView()
        case let .isAbleToUpgrade(latestRelease, currentRelease):
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text(texts.latestTitle).bold()
                    Text(latestRelease.version)
                    Text(texts.currentTitle).bold()
                    if let currentVersion = currentRelease?.version {
                        Text(currentVersion)
                    } else {
                        Text(texts.notReportingDescription)
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
                            }.frame(maxWidth: .infinity)
                        }
                    )
                    .buttonStyle(
                        LargeButtonStyle(
                            backgroundColor: RuuviColor.dustyBlue,
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
                ProgressBar(value: $viewModel.downloadProgress)
                    .frame(height: 16)
                    .padding()
                Text("\(Int(viewModel.downloadProgress * 100))%")
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
                            Text(texts.openCoverTitle)
                            Text(texts.localBootButtonTitle)
                            Text(texts.setUpdatingModeTitle)
                            Text(texts.toBootModeTwoButtonsDescription)
                            Text(texts.toBootModeOneButtonDescription)
                            Text(texts.toBootModeSuccessTitle)
                        }
                        Button(
                            action: {},
                            label: {
                                HStack {
                                    Text(texts.searchingTitle)
                                        .foregroundColor(.secondary)
                                    Spinner(isAnimating: true, style: .medium).eraseToAnyView()
                                }.frame(maxWidth: .infinity)
                            }
                        )
                        .buttonStyle(
                            LargeButtonStyle(
                                backgroundColor: RuuviColor.dustyBlue,
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
                            Text(texts.openCoverTitle)
                            Text(texts.localBootButtonTitle)
                            Text(texts.setUpdatingModeTitle)
                            Text(texts.toBootModeTwoButtonsDescription)
                            Text(texts.toBootModeOneButtonDescription)
                            Text(texts.toBootModeSuccessTitle)
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
                                    .frame(maxWidth: .infinity)
                            }
                        )
                        .buttonStyle(
                            LargeButtonStyle(
                                backgroundColor: RuuviColor.dustyBlue,
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
                ProgressBar(value: $viewModel.flashProgress)
                    .frame(height: 16)
                Text("\(Int(viewModel.flashProgress * 100))%")
                Text(texts.doNotCloseTitle)
                    .bold()
                    .multilineTextAlignment(.center)

            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .eraseToAnyView()
        case .successfulyFlashed(let latestRelease):
            viewModel.storeUpdatedFirmware(latestRelease: latestRelease)
            return Text(texts.successfulTitle)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .padding()
                .eraseToAnyView()
        }
    }

    struct RuuviBoardView: View {
        @State private var isPortrait = false
        private let boardImageName = "ruuvitag-b8-and-older-button-location"
        var body: some View {
            HStack {
                if isPortrait {
                    Image(boardImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Spacer()
                    Image(boardImageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledToFit()
                        .frame(width: 300, height: 147)
                    Spacer()
                }
            }
            .padding()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                guard let scene = UIApplication.shared.windows.first?.windowScene else { return }
                self.isPortrait = scene.interfaceOrientation.isPortrait
            }
        }
    }
}
