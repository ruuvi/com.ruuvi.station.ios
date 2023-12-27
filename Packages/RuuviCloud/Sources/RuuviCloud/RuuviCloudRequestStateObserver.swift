import Foundation

public class RuuviCloudRequestStateObserverManager {
    public static let shared = RuuviCloudRequestStateObserverManager()
    private var cloudRequestStateTokens: [String: NSObjectProtocol] = [:]

    private init() {}

    public func startObserving(
        for macId: String?,
        callback: @escaping (RuuviCloudRequestStateType) -> Void
    ) {
        // Ensures no duplicate observers for the same macId
        guard let macId = macId else { return }
        stopObserving(for: macId)

        let token = NotificationCenter.default.addObserver(
            forName: .RuuviCloudRequestStateDidChange,
            object: nil,
            queue: .main,
            using: { notification in
                guard let userInfo = notification.userInfo,
                      let observedMacId = userInfo[RuuviCloudRequestStateKey.macId] as? String,
                      observedMacId == macId,
                      let state = userInfo[RuuviCloudRequestStateKey.state] as? RuuviCloudRequestStateType else {
                          return
                      }
                callback(state)
            }
        )

        cloudRequestStateTokens[macId] = token
    }

    public func stopObserving(for macId: String?) {
        guard let macId = macId else { return }
        if let token = cloudRequestStateTokens[macId] {
            NotificationCenter.default.removeObserver(token)
            cloudRequestStateTokens[macId] = nil
        }
    }

    public func stopAllObservers() {
        for (macId, _) in cloudRequestStateTokens {
            stopObserving(for: macId)
        }
    }
}
