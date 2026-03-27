import Foundation
import SwiftUI

@MainActor
final class WatchViewModel: ObservableObject {

    @Published var sensors: [WatchSensor] = []
    @Published var isLoading = false
    @Published var isSignedIn = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var settingsRevision = 0

    private let service = WatchCloudService()
    private var refreshTask: Task<Void, Never>?
    private var syncObserver: NSObjectProtocol?

    init() {
        updateSignInState()
        startObservingSyncChanges()
    }

    deinit {
        refreshTask?.cancel()
        if let observer = syncObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public

    func onAppear() {
        if isSignedIn {
            Task { await fetchSensors() }
        }
    }

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            await fetchSensors()
        }
    }

    // MARK: - Private

    private func updateSignInState() {
        isSignedIn = WatchCloudService.storedApiKey() != nil
    }

    private func startObservingSyncChanges() {
        syncObserver = NotificationCenter.default.addObserver(
            forName: .watchSyncDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }

                let wasSignedIn = self.isSignedIn
                self.updateSignInState()
                self.settingsRevision += 1

                if self.isSignedIn {
                    if !wasSignedIn || self.sensors.isEmpty {
                        await self.fetchSensors()
                    }
                } else {
                    self.sensors = []
                }
            }
        }
    }

    private func fetchSensors() async {
        guard isSignedIn else { return }
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await service.fetchSensors()
            sensors = fetched.sorted { $0.displayName < $1.displayName }
            lastUpdated = Date()
        } catch WatchCloudService.ServiceError.notAuthorized {
            isSignedIn = false
            sensors = []
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
