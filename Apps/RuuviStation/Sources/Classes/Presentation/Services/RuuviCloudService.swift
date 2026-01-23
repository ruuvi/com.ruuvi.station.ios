import Foundation
import RuuviService
import RuuviDaemon
import RuuviUser
import RuuviLocal
import RuuviCore
import RuuviOntology

protocol RuuviCloudServiceDelegate: AnyObject {
    func ruuviCloudService(
        _ service: RuuviCloudService,
        userDidLogin loggedIn: Bool
    )
    func ruuviCloudService(
        _ service: RuuviCloudService,
        userDidLogOut loggedOut: Bool
    )
    func ruuviCloudService(
        _ service: RuuviCloudService,
        syncStatusDidChange isRefreshing: Bool
    )
    func ruuviCloudService(
        _ service: RuuviCloudService,
        syncDidComplete: Bool
    )
    func ruuviCloudService(
        _ service: RuuviCloudService,
        historySyncInProgress inProgress: Bool,
        for macId: String
    )
    func ruuviCloudService(
        _ service: RuuviCloudService,
        authorizationFailed: Bool
    )
    func ruuviCloudService(
        _ service: RuuviCloudService,
        cloudModeDidChange isEnabled: Bool
    )
}

class RuuviCloudService {

    // MARK: - Dependencies
    private let cloudSyncDaemon: RuuviDaemonCloudSync
    private let cloudSyncService: RuuviServiceCloudSync
    private let cloudNotificationService: RuuviServiceCloudNotification
    private let authService: RuuviServiceAuth
    private let ruuviUser: RuuviUser

    private var settings: RuuviLocalSettings
    private var pnManager: RuuviCorePN

    // MARK: - Properties
    weak var delegate: RuuviCloudServiceDelegate?

    // MARK: - Observation Tokens
    private var authLoginToken: NSObjectProtocol?
    private var authLogoutToken: NSObjectProtocol?
    private var cloudModeToken: NSObjectProtocol?
    private var cloudSyncSuccessStateToken: NSObjectProtocol?
    private var cloudSyncHistoryToken: NSObjectProtocol?
    private var cloudSyncFailStateToken: NSObjectProtocol?

    // MARK: - Initialization
    init(
        cloudSyncDaemon: RuuviDaemonCloudSync,
        cloudSyncService: RuuviServiceCloudSync,
        cloudNotificationService: RuuviServiceCloudNotification,
        authService: RuuviServiceAuth,
        ruuviUser: RuuviUser,
        settings: RuuviLocalSettings,
        pnManager: RuuviCorePN
    ) {
        self.cloudSyncDaemon = cloudSyncDaemon
        self.cloudSyncService = cloudSyncService
        self.cloudNotificationService = cloudNotificationService
        self.authService = authService
        self.ruuviUser = ruuviUser
        self.settings = settings
        self.pnManager = pnManager
    }

    deinit {
        stopObserving()
    }

    // MARK: - Public Interface
    func startObserving() {
        startObservingCloudSync()
        observeAuthStateChange()
    }

    func startObservingCloudSync() {
        observeCloudModeChanges()
        observeCloudSyncStatus()
    }

    func stopObserving() {
        cloudModeToken?.invalidate()
        cloudSyncSuccessStateToken?.invalidate()
        cloudSyncHistoryToken?.invalidate()
        cloudSyncFailStateToken?.invalidate()
        authLoginToken?.invalidate()
        authLogoutToken?.invalidate()

        cloudModeToken = nil
        cloudSyncSuccessStateToken = nil
        cloudSyncHistoryToken = nil
        cloudSyncFailStateToken = nil
        authLoginToken = nil
        authLogoutToken = nil
    }

    func triggerImmediateSync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.cloudSyncDaemon.refreshImmediately()
        }
    }

    func triggerFullHistorySync() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            if self.settings.historySyncOnDashboard &&
               (!self.settings.historySyncLegacy || !self.settings.historySyncForEachSensor) {
                Task {
                    _ = try? await self.cloudSyncService.syncAllHistory()
                }
            }
        }
    }

    func handleCloudModeToggle() {
        delegate?.ruuviCloudService(self, cloudModeDidChange: settings.cloudModeEnabled)
    }

    func isAuthorized() -> Bool {
        return ruuviUser.isAuthorized
    }

    func getUserEmail() -> String? {
        return ruuviUser.email
    }

    func forceLogout() {
        guard ruuviUser.isAuthorized else { return }

        // Unregister push notifications
        if let token = pnManager.fcmToken, !token.isEmpty {
            Task { [weak self] in
                guard let self else { return }
                _ = try? await cloudNotificationService.unregister(token: token, tokenId: nil)
                self.pnManager.fcmToken = nil
                self.pnManager.fcmTokenLastRefreshed = nil
            }
        }

        // Perform logout
        Task { [weak self] in
            guard let self = self else { return }

            do {
                _ = try await authService.logout()

                // Stop observing cloud mode state to avoid simultaneous access
                cloudModeToken?.invalidate()
                cloudModeToken = nil

                // Disable cloud mode
                settings.cloudModeEnabled = false

                // Notify delegate
                delegate?.ruuviCloudService(self, cloudModeDidChange: false)

                // Restart cloud mode observation
                observeCloudModeChanges()
            } catch {
                // ignore error to match previous behavior
            }

            // Logout completed
            delegate?.ruuviCloudService(self, authorizationFailed: true)
        }
    }
}

// MARK: - Private Implementation
private extension RuuviCloudService {

    func observeCloudModeChanges() {
        cloudModeToken?.invalidate()
        cloudModeToken = NotificationCenter.default.addObserver(
            forName: .CloudModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.handleCloudModeToggle()
        }
    }

    // swiftlint:disable:next function_body_length
    func observeCloudSyncStatus() {
        // Observe sync success/completion
        cloudSyncSuccessStateToken?.invalidate()
        cloudSyncSuccessStateToken = NotificationCenter.default.addObserver(
            forName: .NetworkSyncDidChangeCommonStatus,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            guard let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus else {
                return
            }

            switch status {
            case .syncing:
                self.delegate?.ruuviCloudService(self, syncStatusDidChange: true)

            case .complete:
                self.delegate?.ruuviCloudService(self, syncStatusDidChange: false)
                self.delegate?.ruuviCloudService(self, syncDidComplete: true)

            default:
                self.delegate?.ruuviCloudService(self, syncStatusDidChange: false)
            }
        }

        // History sync
        cloudSyncHistoryToken?.invalidate()
        cloudSyncHistoryToken = NotificationCenter
            .default
            .addObserver(
                forName: .NetworkSyncHistoryDidChangeStatus,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let sSelf = self,
                          let mac = notification.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier,
                          let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus
                    else {
                        return
                    }

                    switch status {
                    case .syncing:
                        sSelf.delegate?.ruuviCloudService(
                            sSelf,
                            historySyncInProgress: true,
                            for: mac.value
                        )

                    default:
                        sSelf.delegate?.ruuviCloudService(
                            sSelf,
                            historySyncInProgress: false,
                            for: mac.value
                        )
                    }
                }
            )

        // Observe sync failures due to authorization
        cloudSyncFailStateToken?.invalidate()
        cloudSyncFailStateToken = NotificationCenter.default.addObserver(
            forName: .NetworkSyncDidFailForAuthorization,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.forceLogout()
        }
    }

    func observeAuthStateChange() {
        authLogoutToken?.invalidate()
        authLogoutToken = NotificationCenter.default.addObserver(
            forName: .RuuviAuthServiceDidLogout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.ruuviCloudService(self, userDidLogOut: true)
        }
    }
}

// MARK: - Cloud Mode Management
extension RuuviCloudService {
    func isCloudModeEnabled() -> Bool {
        return settings.cloudModeEnabled
    }
}
