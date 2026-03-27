import SwiftUI

struct SensorListView: View {

    @StateObject private var viewModel = WatchViewModel()
    private let appGroupDefaults = UserDefaults(suiteName: WatchSharedDefaults.suiteName)

    var body: some View {
        let revision = viewModel.settingsRevision

        Group {
            if !viewModel.isSignedIn {
                notSignedInView
            } else if viewModel.isLoading && viewModel.sensors.isEmpty {
                loadingView
            } else if viewModel.sensors.isEmpty {
                emptyView
            } else {
                sensorList
            }
        }
        .id(revision)
        .onAppear {
            viewModel.onAppear()
        }
    }

    // MARK: - Sensor list

    private var sensorList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.sensors) { sensor in
                    SensorCardView(sensor: sensor, appGroupDefaults: appGroupDefaults)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .navigationTitle("Ruuvi")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }

    // MARK: - State views

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Loading…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var notSignedInView: some View {
        VStack(spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Sign in to Ruuvi Station on your iPhone to view cloud sensors.")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("Connect") {
                WatchSessionManager.shared.requestApiKeyFromPhone()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "sensor")
                .font(.title2)
                .foregroundStyle(.secondary)
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            } else {
                Text("No cloud sensors found.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            Button("Retry") {
                viewModel.refresh()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
        }
        .padding()
    }
}
