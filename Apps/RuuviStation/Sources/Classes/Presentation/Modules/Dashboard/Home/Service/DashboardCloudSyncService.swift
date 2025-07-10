import Foundation
import RuuviService
import RuuviDaemon
import RuuviUser
import RuuviLocal
import RuuviCore

protocol DashboardCloudSyncServiceDelegate: AnyObject {
    func cloudSyncService(
        _ service: DashboardCloudSyncService,
        userDidLogin loggedIn: Bool
    )
    func cloudSyncService(
        _ service: DashboardCloudSyncService,
        userDidLogOut loggedOut: Bool
    )
    func cloudSyncService(
        _ service: DashboardCloudSyncService,
        syncStatusDidChange isRefreshing: Bool
    )
    func cloudSyncService(
        _ service: DashboardCloudSyncService,
        syncDidComplete: Bool
    )
    func cloudSyncService(
        _ service: DashboardCloudSyncService,
        authorizationFailed: Bool
    )
    func cloudSyncService(
        _ service: DashboardCloudSyncService,
        cloudModeDidChange isEnabled: Bool
    )
}

class DashboardCloudSyncService {

    // MARK: - Dependencies
    private let cloudSyncDaemon: RuuviDaemonCloudSync
    private let cloudSyncService: RuuviServiceCloudSync
    private let cloudNotificationService: RuuviServiceCloudNotification
    private let authService: RuuviServiceAuth
    private let ruuviUser: RuuviUser

    private var settings: RuuviLocalSettings
    private var pnManager: RuuviCorePN

    // MARK: - Properties
    weak var delegate: DashboardCloudSyncServiceDelegate?

    // MARK: - Observation Tokens
    private var authLoginToken: NSObjectProtocol?
    private var authLogoutToken: NSObjectProtocol?
    private var cloudModeToken: NSObjectProtocol?
    private var cloudSyncSuccessStateToken: NSObjectProtocol?
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
        cloudSyncFailStateToken?.invalidate()
        authLoginToken?.invalidate()
        authLogoutToken?.invalidate()

        cloudModeToken = nil
        cloudSyncSuccessStateToken = nil
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
                self.cloudSyncService.syncAllHistory()
            }
        }
    }

    func handleCloudModeToggle() {
        delegate?.cloudSyncService(self, cloudModeDidChange: settings.cloudModeEnabled)
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
            cloudNotificationService.unregister(token: token, tokenId: nil)
                .on(success: { [weak self] _ in
                    self?.pnManager.fcmToken = nil
                    self?.pnManager.fcmTokenLastRefreshed = nil
                })
        }

        // Perform logout
        authService.logout()
            .on(success: { [weak self] _ in
                guard let self = self else { return }

                // Stop observing cloud mode state to avoid simultaneous access
                self.cloudModeToken?.invalidate()
                self.cloudModeToken = nil

                // Disable cloud mode
                self.settings.cloudModeEnabled = false

                // Notify delegate
                self.delegate?.cloudSyncService(self, cloudModeDidChange: false)

                // Restart cloud mode observation
                self.observeCloudModeChanges()

            }, completion: { [weak self] in
                // Logout completed
                guard let self = self else { return }
                self.delegate?.cloudSyncService(self, authorizationFailed: true)
            })
    }
}

// MARK: - Private Implementation
private extension DashboardCloudSyncService {

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
                self.delegate?.cloudSyncService(self, syncStatusDidChange: true)

            case .complete:
                self.delegate?.cloudSyncService(self, syncStatusDidChange: false)
                self.delegate?.cloudSyncService(self, syncDidComplete: true)

            default:
                self.delegate?.cloudSyncService(self, syncStatusDidChange: false)
            }
        }

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
            self.delegate?.cloudSyncService(self, userDidLogOut: true)
        }
    }
}

// MARK: - Cloud Mode Management
extension DashboardCloudSyncService {
    func isCloudModeEnabled() -> Bool {
        return settings.cloudModeEnabled
    }
}
