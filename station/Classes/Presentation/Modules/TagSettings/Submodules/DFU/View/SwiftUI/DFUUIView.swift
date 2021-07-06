import SwiftUI
import Localize_Swift

struct DFUUIView: View {
    @ObservedObject var viewModel: DFUViewModel

    var body: some View {
        VStack {
            content
                .navigationBarTitle(
                    "Firmware Update",
                    displayMode: .inline
                )
        }
        .onAppear { self.viewModel.send(event: .onAppear) }
    }

    private var content: some View {
        switch viewModel.state {
        case .idle:
            return Color.clear.eraseToAnyView()
        case .loading:
            return VStack(alignment: .leading, spacing: 16) {
                Text("Latest available Ruuvi Firmware version:").bold()
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
                Text("Latest available Ruuvi Firmware version:").bold()
                Text(latestRelease.version)
                Text("Current version:").bold()
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
                Text("Latest available Ruuvi Firmware version:").bold()
                Text(latestRelease.version)
                Text("Current version:").bold()
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
                Text("Latest available Ruuvi Firmware version:").bold()
                Text(latestRelease.version)
                Text("Current version:").bold()
                if let currentVersion = currentRelease?.version {
                    Text(currentVersion)
                } else {
                    Text("Your sensor doesn't report it's current firmware version. That means that it's probably running an old firmware version and updating is recommended")
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
        case let .noNeedToUpgrade(latestRelease, _):
            return Text("You are running the latest firmware version \(latestRelease.version), no need to upgrade")
                .multilineTextAlignment(.center)
                .padding()
                .eraseToAnyView()
        case let .isAbleToUpgrade(latestRelease, currentRelease):
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Latest available Ruuvi Firmware version:").bold()
                    Text(latestRelease.version)
                    Text("Current version:").bold()
                    if let currentVersion = currentRelease?.version {
                        Text(currentVersion)
                    } else {
                        Text("Your sensor doesn't report it's current firmware version. That means that it's probably running an old firmware version and updating is recommended")
                    }
                    Button(
                        action: {
                            self.viewModel.send(
                                event: .onStartUpgrade(latestRelease, currentRelease)
                            )
                        },
                        label: {
                            HStack {
                                Text("Start updating process")
                            }.frame(maxWidth: .infinity)
                        }
                    )
                    .buttonStyle(
                        LargeButtonStyle(
                            backgroundColor: RuuviColor.purple,
                            foregroundColor: Color.white,
                            isDisabled: false
                        )
                    )
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
            return VStack {
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }.eraseToAnyView()
        case .downloading:
            return VStack(alignment: .center, spacing: 16) {
                Text("Downloading the latest firmware to be updated...")
                ProgressBar(value: $viewModel.downloadProgress)
                    .frame(height: 20)
                    .padding()
                Text("\(Int(viewModel.downloadProgress * 100))%")
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .eraseToAnyView()
        case .listening:
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Prepare your sensor").bold()
                    Text("1. Open the cover of your Ruuvi sensor")
                    Text("2. Set the sensor to updating mode")
                    Text("If your sensor has two buttons, press the R button while keeping pressed the B button")
                    Text("If your sensor has one button, keep the button pressed for ten seconds")
                    Text("3. When successful you will see a continuous red light")
                }

                Button(
                    action: {},
                    label: {
                        HStack {
                            Text("Searching for a sensor")
                            Spinner(isAnimating: true, style: .medium).eraseToAnyView()
                        }.frame(maxWidth: .infinity)
                    }
                )
                .buttonStyle(
                    LargeButtonStyle(
                        backgroundColor: RuuviColor.purple,
                        foregroundColor: Color.white,
                        isDisabled: true
                    )
                )
                .disabled(true)
                .frame(maxWidth: .infinity)
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .eraseToAnyView()
        case let .readyToUpdate(latestRelease, currentRelease, uuid, appUrl, fullUrl):
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Prepare your sensor").bold()
                    Text("1. Open the cover of your Ruuvi sensor")
                    Text("2. Set the sensor to updating mode")
                    Text("If your sensor has two buttons, press the R button while keeping pressed the B button")
                    Text("If your sensor has one button, keep the button pressed for ten seconds")
                    Text("3. When successful you will see a continuous red light")
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
                        Text("Start the update")
                            .frame(maxWidth: .infinity)
                    }
                )
                .buttonStyle(
                    LargeButtonStyle(
                        backgroundColor: RuuviColor.purple,
                        foregroundColor: Color.white,
                        isDisabled: false
                    )
                )
                .frame(maxWidth: .infinity)
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .padding()
            .eraseToAnyView()
        case .flashing:
            return VStack(alignment: .center, spacing: 24) {
                Text("Updating...")
                ProgressBar(value: $viewModel.flashProgress)
                    .frame(height: 12)
                Text("\(Int(viewModel.flashProgress * 100))%")
                Text("Do not close or power off the sensor during the update.")
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
        case .successfulyFlashed:
            return Text("Update successful")
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .padding()
                .eraseToAnyView()
        }
    }
}
