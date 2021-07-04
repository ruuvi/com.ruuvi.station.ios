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
            .padding(16)
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
            .padding(16)
            .onAppear { self.viewModel.send(event: .onLoaded(latestRelease)) }
            .eraseToAnyView()
        case let .serving(latestRelease):
            return VStack(alignment: .leading, spacing: 16) {
                Text("Latest available Ruuvi Firmware version:").bold()
                Text(latestRelease.version)
                Text("Current version:").bold()
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }
            .padding(16)
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
            .padding(16)
            .onAppear { self.viewModel.send(event: .onLoadedAndServed(latestRelease, currentRelease)) }
            .eraseToAnyView()
        case let .noNeedToUpgrade(latestRelease, _):
            return Text("You are running the latest firmware version \(latestRelease.version), no need to upgrade")
                .padding(16)
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
                }.padding(16)
                LargeButton(
                    title: "Start updating process",
                    backgroundColor: RuuviColor.purple
                ) {
                    self.viewModel.send(event: .onStartUpgrade(latestRelease))
                }.padding(16)
            }.eraseToAnyView()
        case .reading:
            return VStack {
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }.eraseToAnyView()
        case .downloading:
            return VStack(alignment: .center, spacing: 16) {
                Text("Downloading the latest firmware to be updated...")
                ProgressBar(value: $viewModel.downloadProgress)
                    .frame(height: 20)
                    .padding(16)
                Text("\(Int(viewModel.downloadProgress * 100))%")
            }.eraseToAnyView()
        case .listening:
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Prepare your sensor").bold()
                    Text("1. Open the cover of your Ruuvi sensor")
                    Collapsible(
                        label: { Text("2. Set the sensor to updating mode") },
                        content: {
                            Image("ruuvi-tag-firmware-update")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .allowsHitTesting(false)
                        }
                    )
                    Text("If your sensor has two buttons, press the R button while keeping pressed the B button")
                    Text("If your sensor has one button, keep the button pressed for ten seconds")
                    Text("3. When successful you will see a continuous red light")
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                LargeButton(
                    title: "Searching for a sensor",
                    disabled: true,
                    backgroundColor: RuuviColor.purple,
                    action: {}
                )
            }
            .padding(16)
            .eraseToAnyView()
        case let .readyToUpdate(uuid, fileUrl):
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Prepare your sensor").bold()
                    Text("1. Open the cover of your Ruuvi sensor")
                    Collapsible(
                        label: { Text("2. Set the sensor to updating mode") },
                        content: {
                            Image("ruuvi-tag-firmware-update")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .allowsHitTesting(false)
                        }
                    )
                    Text("If your sensor has two buttons, press the R button while keeping pressed the B button")
                    Text("If your sensor has one button, keep the button pressed for ten seconds")
                    Text("3. When successful you will see a continuous red light")
                }
                LargeButton(
                    title: "Start the update",
                    backgroundColor: RuuviColor.purple,
                    action: {
                        self.viewModel.send(
                            event: .onUserDidConfirmToFlash(uuid: uuid, fileUrl: fileUrl)
                        )
                    }
                )
            }
            .padding(16)
            .eraseToAnyView()
        case .flashing:
            return VStack(alignment: .center, spacing: 16) {
                Text("Updating...")
                ProgressBar(value: $viewModel.flashProgress)
                    .frame(height: 20)
                    .padding(16)
                Text("\(Int(viewModel.flashProgress * 100))%")
                Text("Do not close or power off the sensor during the update.")

            }.eraseToAnyView()
        case .successfulyFlashed:
            return Text("Update successful").eraseToAnyView()
        }
    }
}
