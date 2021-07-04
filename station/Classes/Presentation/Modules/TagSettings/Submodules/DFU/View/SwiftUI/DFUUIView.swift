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
                    backgroundColor: Color.purple
                ) {
                    self.viewModel.send(event: .onStartUpgrade(latestRelease))
                }
            }.eraseToAnyView()
        case .reading:
            return VStack {
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }.eraseToAnyView()
        case .downloading:
            return VStack {
                ProgressBar(value: $viewModel.downloadProgress)
                    .frame(height: 20)
                    .padding(16)
            }.eraseToAnyView()
        case .listening:
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Prepare your sensor")
                    Text("1. Open the cover of your Ruuvi sensor")
                    Text("2. Set the sensor to updating mode")
                    Text("If your sensor has two buttons, press the R button while keeping pressed the B buttom")
                    Text("If your sensor has one button, keep the button pressed for ten seconds")
                    Text("3. When successful you will see a continuous red light")
                }
                LargeButton(
                    title: "Searching for a sensor",
                    disabled: true,
                    backgroundColor: Color.purple,
                    action: {}
                )
            }
            .padding(16)
            .eraseToAnyView()
        case let .readyToUpdate(uuid, fileUrl):
            return VStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Prepare your sensor")
                    Text("1. Open the cover of your Ruuvi sensor")
                    Text("2. Set the sensor to updating mode")
                    Text("If your sensor has two buttons, press the R button while keeping pressed the B buttom")
                    Text("If your sensor has one button, keep the button pressed for ten seconds")
                    Text("3. When successful you will see a continuous red light")
                }
                LargeButton(
                    title: "Start the update",
                    backgroundColor: Color.purple,
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
            return VStack {
                ProgressBar(value: $viewModel.flashProgress)
                    .frame(height: 20)
                    .padding(16)
            }.eraseToAnyView()
        case .successfulyFlashed:
            return Text("Update successful").eraseToAnyView()
        }
    }
}
