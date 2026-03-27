import Foundation
import WatchConnectivity

final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()
    private let appGroupDefaults = UserDefaults(suiteName: WatchSharedDefaults.suiteName)

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Ask the paired iPhone to push its current API key.
    /// Uses sendMessage when reachable, otherwise queues via transferUserInfo.
    func requestApiKeyFromPhone() {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = ["type": "requestApiKey"]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            // transferUserInfo is queued and delivered without needing reachability
            WCSession.default.transferUserInfo(message)
        }
    }

    /// Ask the paired iPhone to trigger an immediate cloud refresh.
    func requestRefresh() {
        guard WCSession.default.activationState == .activated else { return }
        let message: [String: Any] = ["type": "requestRefresh"]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(message)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }

        // Check for a context the iPhone already sent in a previous session
        applyReceivedPayload(session.receivedApplicationContext)

        // No stored key yet — request one from the iPhone
        if WatchCloudService.storedApiKey() == nil {
            requestApiKeyFromPhone()
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        applyReceivedPayload(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        applyReceivedPayload(message)
    }

    // Handles responses from transferUserInfo (iOS → Watch direction)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        applyReceivedPayload(userInfo)
    }

    private func applyReceivedPayload(_ payload: [String: Any]) {
        guard !payload.isEmpty else { return }

        var authChanged = false
        var settingsChanged = false

        if let apiKey = payload["apiKey"] as? String {
            let currentApiKey = WatchCloudService.storedApiKey()
            if currentApiKey != apiKey {
                WatchCloudService.storeApiKey(apiKey)
                authChanged = true
            }
        } else if let signedOut = payload["signedOut"] as? Bool, signedOut {
            if WatchCloudService.storedApiKey() != nil {
                WatchCloudService.storeApiKey(nil)
                authChanged = true
            }
        }

        WatchSharedDefaults.syncedSettingKeys.forEach { key in
            if let intValue = payload[key] as? Int {
                let currentValue = appGroupDefaults?.object(forKey: key) as? Int
                if currentValue != intValue {
                    appGroupDefaults?.set(intValue, forKey: key)
                    settingsChanged = true
                }
            } else if let boolValue = payload[key] as? Bool {
                let currentValue = appGroupDefaults?.object(forKey: key) as? Bool
                if currentValue != boolValue {
                    appGroupDefaults?.set(boolValue, forKey: key)
                    settingsChanged = true
                }
            } else if let stringValue = payload[key] as? String {
                let currentValue = appGroupDefaults?.string(forKey: key)
                if currentValue != stringValue {
                    appGroupDefaults?.set(stringValue, forKey: key)
                    settingsChanged = true
                }
            }
        }

        guard authChanged || settingsChanged else { return }

        NotificationCenter.default.post(
            name: .watchSyncDidChange,
            object: nil,
            userInfo: ["authChanged": authChanged]
        )
    }
}

extension Notification.Name {
    static let watchAuthDidChange = Notification.Name("WatchSessionManager.watchAuthDidChange")
    static let watchSyncDidChange = Notification.Name("WatchSessionManager.watchSyncDidChange")
}
