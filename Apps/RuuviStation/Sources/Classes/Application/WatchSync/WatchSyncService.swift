import Foundation
import WatchConnectivity
import RuuviUser

/// Bridges authentication state from the iOS app to the Apple Watch companion app.
final class WatchSyncService: NSObject {

    // MARK: - Constants

    private static let appGroupID = AppGroupConstants.appGroupSuiteIdentifier
    private static let apiKeyUD   = AppGroupConstants.watchApiKeyKey

    // MARK: - Dependencies

    private let ruuviUser: RuuviUser
    private let appGroupDefaults = UserDefaults(
        suiteName: AppGroupConstants.appGroupSuiteIdentifier
    )
    private var refreshHandler: (() -> Void)?
    private var defaultsObserver: NSObjectProtocol?

    // MARK: - Lifecycle

    init(ruuviUser: RuuviUser, refreshHandler: (() -> Void)? = nil) {
        self.ruuviUser = ruuviUser
        self.refreshHandler = refreshHandler
        super.init()
    }

    func start() {
        observeAuthNotifications()
        observeSharedDefaultsChanges()
        activateWCSession()
        syncCurrentStateToWatch()
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    // MARK: - Auth observation

    private func observeAuthNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserAuthorized),
            name: .RuuviUserDidAuthorized,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUserSignedOut),
            name: .RuuviUserDidLogout,
            object: nil
        )
    }

    private func observeSharedDefaultsChanges() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: appGroupDefaults,
            queue: .main
        ) { [weak self] _ in
            self?.sendCurrentContextViaWCSession()
        }
    }

    @objc private func handleUserAuthorized() {
        syncCurrentStateToWatch()
    }

    @objc private func handleUserSignedOut() {
        clearApiKeyFromSharedStorage()
        sendCurrentContextViaWCSession()
    }

    // MARK: - App Group persistence

    private func syncCurrentStateToWatch() {
        syncApiKeyToSharedStorage()
        sendCurrentContextViaWCSession()
    }

    private func syncApiKeyToSharedStorage() {
        guard let apiKey = ruuviUser.apiKey, !apiKey.isEmpty else {
            clearApiKeyFromSharedStorage()
            return
        }
        appGroupDefaults?.set(apiKey, forKey: Self.apiKeyUD)
    }

    private func clearApiKeyFromSharedStorage() {
        appGroupDefaults?.removeObject(forKey: Self.apiKeyUD)
    }

    // MARK: - WCSession

    private func activateWCSession() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func sendCurrentContextViaWCSession() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated
        else { return }

        let context = buildApplicationContext()
        try? WCSession.default.updateApplicationContext(context)

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(context, replyHandler: nil, errorHandler: nil)
        }
    }

    private func buildApplicationContext() -> [String: Any] {
        var context: [String: Any] = [:]

        if let apiKey = ruuviUser.apiKey, !apiKey.isEmpty {
            context["apiKey"] = apiKey
        } else {
            context["signedOut"] = true
        }

        AppGroupConstants.watchSyncedSettingsKeys.forEach { key in
            if let value = appGroupDefaults?.object(forKey: key) {
                context[key] = value
            }
        }

        return context
    }
}

// MARK: - WCSessionDelegate

extension WatchSyncService: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            sendCurrentContextViaWCSession()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleWatchRequest(message)
    }

    // Handles requests queued via transferUserInfo (sent when not reachable)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleWatchRequest(userInfo)
    }

    private func handleWatchRequest(_ message: [String: Any]) {
        switch message["type"] as? String {
        case "requestApiKey":
            sendCurrentContextViaWCSession()
        case "requestRefresh":
            DispatchQueue.main.async { [weak self] in
                self?.refreshHandler?()
            }
        default:
            break
        }
    }
}
