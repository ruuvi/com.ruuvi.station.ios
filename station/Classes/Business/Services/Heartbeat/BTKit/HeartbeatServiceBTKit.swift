import Foundation
import BTKit

class HeartbeatServiceBTKit: HeartbeatService {
    
    var errorPresenter: ErrorPresenter!
    var background: BTBackground!
    var localNotificationsManager: LocalNotificationsManager!
    var connectionPersistence: ConnectionPersistence!
    
    private var connectTokens = [String: ObservationToken]()
    private var disconnectTokens = [String: ObservationToken]()
    private var connectionAddedToken: NSObjectProtocol?
    private var connectionRemovedToken: NSObjectProtocol?
    
    init() {
        connectionAddedToken = NotificationCenter.default.addObserver(forName: .ConnectionPersistenceDidStartToKeepConnection, object: nil, queue: .main, using: { [weak self] (notification) in
            if let userInfo = notification.userInfo, let uuid = userInfo[ConnectionPersistenceDidStartToKeepConnectionKey.uuid] as? String {
                self?.connect(uuid: uuid)
            }
        })
        
        connectionRemovedToken = NotificationCenter.default.addObserver(forName: .ConnectionPersistenceDidStopToKeepConnection, object: nil, queue: .main, using: { [weak self] (notification) in
            if let userInfo = notification.userInfo, let uuid = userInfo[ConnectionPersistenceDidStopToKeepConnectionKey.uuid] as? String {
                self?.disconnect(uuid: uuid)
            }
        })
    }
    
    deinit {
        invalidateTokens()
        if let connectionAddedToken = connectionAddedToken {
            NotificationCenter.default.removeObserver(connectionAddedToken)
        }
        if let connectionRemovedToken = connectionRemovedToken {
            NotificationCenter.default.removeObserver(connectionRemovedToken)
        }
    }
    
    func start() {
        invalidateTokens()
        connectionPersistence.keepConnectionUUIDs.forEach({ connect(uuid: $0)})
    }
    
    func stop() {
        invalidateTokens()
        connectionPersistence.keepConnectionUUIDs.forEach({ disconnect(uuid: $0) })
        
    }
    
    private func connect(uuid: String) {
        disconnectTokens[uuid]?.invalidate()
        connectTokens[uuid] = background.connect(for: self, uuid: uuid, connected: { (observer, result) in
            switch result {
            case .failure(let error):
                observer.errorPresenter.present(error: error)
            case .disconnected:
                if observer.connectionPersistence.presentConnectionNotifications(for: uuid) {
                    observer.localNotificationsManager.showDidDisconnect(uuid: uuid)
                }
            case .already:
                break // do nothing
            case .just:
                if observer.connectionPersistence.presentConnectionNotifications(for: uuid) {
                    observer.localNotificationsManager.showDidConnect(uuid: uuid)
                }
            }
        }, heartbeat: { observer, device in
            
        }, disconnected: { observer, result in
            switch result {
            case .failure(let error):
                observer.errorPresenter.present(error: error)
            case .stillConnected:
                break // do nothing
            case .already:
                break // do nothing
            case .just:
                if observer.connectionPersistence.presentConnectionNotifications(for: uuid) {
                    observer.localNotificationsManager.showDidDisconnect(uuid: uuid)
                }
            }
        })
    }
    
    private func disconnect(uuid: String) {
        connectTokens[uuid]?.invalidate()
        disconnectTokens[uuid] = background.disconnect(for: self, uuid: uuid, result: { (observer, result) in
            switch result {
            case .failure(let error):
                observer.errorPresenter.present(error: error)
            case .just:
                if observer.connectionPersistence.presentConnectionNotifications(for: uuid) {
                    observer.localNotificationsManager.showDidDisconnect(uuid: uuid)
                }
            case .already:
                break // do nothing
            case .stillConnected:
                break // do nothing
            }
        })
    }
    
    private func invalidateTokens() {
        connectTokens.values.forEach({ $0.invalidate() })
        connectTokens.removeAll()
        disconnectTokens.values.forEach({ $0.invalidate() })
        disconnectTokens.removeAll()
    }
}
