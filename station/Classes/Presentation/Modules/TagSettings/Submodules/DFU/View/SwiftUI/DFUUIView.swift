import SwiftUI
import Localize_Swift

struct DFUUIView: View {
    @ObservedObject var viewModel: DFUViewModel

    var body: some View {
        NavigationView {
            content
                .navigationBarTitle("Firmware Update".localized())
        }
        .onAppear { self.viewModel.send(event: .onAppear) }
    }

    private var content: some View {
        switch viewModel.state {
        case .idle:
            return Color.clear.eraseToAnyView()
        case .loading:
            return VStack {
                Text("Latest available Ruuvi Firmware version:")
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }.eraseToAnyView()
        case .error(let error):
            return Text(error.localizedDescription).eraseToAnyView()
        case let .loaded(latestRelease):
            return VStack {
                Text("Latest available Ruuvi Firmware version:")
                Text(latestRelease.version)
                Text("Current version:")
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }
            .onAppear { self.viewModel.send(event: .onLoaded(latestRelease)) }
            .eraseToAnyView()
        case let .serving(latestRelease):
            return VStack {
                Text("Latest available Ruuvi Firmware version:")
                Text(latestRelease.version)
                Text("Current version:")
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }
            .eraseToAnyView()
        case let .checking(latestRelease, currentRelease):
            return VStack {
                Text("Latest available Ruuvi Firmware version:")
                Text(latestRelease.version)
                Text("Current version:")
                if let currentVersion = currentRelease?.version {
                    Text(currentVersion)
                } else {
                    Text("Your sensor doesn't report it's current firmware version. That means that it's probably running an old firmware version and updating is recommended")
                }

            }
            .onAppear { self.viewModel.send(event: .onLoadedAndServed(latestRelease, currentRelease)) }
            .eraseToAnyView()
        case let .noNeedToUpgrade(latestRelease, _):
            return Text("You are running the latest firmware version \(latestRelease.version), no need to upgrade")
                .eraseToAnyView()
        case let .isAbleToUpgrade(latestRelease, currentRelease):
            return VStack {
                Text("Latest available Ruuvi Firmware version:")
                Text(latestRelease.version)
                Text("Current version:")
                if let currentVersion = currentRelease?.version {
                    Text(currentVersion)
                } else {
                    Text("Your sensor doesn't report it's current firmware version. That means that it's probably running an old firmware version and updating is recommended")
                }
                Button(
                    "Start updating process",
                    action: {
                        self.viewModel.send(event: .onStartUpgrade(latestRelease))
                    }
                )

            }.eraseToAnyView()
        case .reading:
            return VStack {
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }.eraseToAnyView()
        case .downloading:
            return VStack {
                ProgressBar(value: $viewModel.downloadProgress).frame(height: 20)
            }.eraseToAnyView()
        case .listening:
            return VStack {
                Text("Prepare your sensor")
                Text("1. Open the cover of your Ruuvi sensor")
                Text("2. Set the sensor to updating mode")
                Text("If your sensor has two buttons, press the R button while keeping pressed the B buttom")
                Text("If your sensor has one button, keep the button pressed for ten seconds")
                Text("3. When successful you will see a continuous red light")
                Button("Searching for a sensor", action: {}).disabled(true)
            }.eraseToAnyView()
        }
    }
}
