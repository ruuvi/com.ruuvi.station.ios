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
        case let .reading(latestRelease):
            return VStack {
                Text("Latest available Ruuvi Firmware version:")
                Text(latestRelease.version)
                Text("Current version:")
                Spinner(isAnimating: true, style: .medium).eraseToAnyView()
            }
            .eraseToAnyView()
        case let .ready(latestRelease, currentRelease):
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
            .onAppear { self.viewModel.send(event: .onReady(latestRelease, currentRelease)) }
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
        }
    }
}
