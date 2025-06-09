import Foundation
import RuuviOntology

protocol DaemonErrorServiceProtocol: AnyObject {
    var onDaemonError: ((Error) -> Void)? { get set }
    
    func startObservingDaemonErrors()
    func stopObservingDaemonErrors()
}

final class DaemonErrorService: DaemonErrorServiceProtocol {
    // MARK: - Properties
    var onDaemonError: ((Error) -> Void)?
    
    // MARK: - Private Properties
    private var ruuviTagAdvertisementDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagPropertiesDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagHeartbeatDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagReadLogsOperationFailureToken: NSObjectProtocol?
    
    // MARK: - Initialization
    init() {}
    
    deinit {
        stopObservingDaemonErrors()
    }
    
    // MARK: - Public Methods
    func startObservingDaemonErrors() {
        observeAdvertisementDaemonFailures()
        observePropertiesDaemonFailures()
        observeHeartbeatDaemonFailures()
        observeReadLogsOperationFailures()
    }
    
    func stopObservingDaemonErrors() {
        ruuviTagAdvertisementDaemonFailureToken?.invalidate()
        ruuviTagPropertiesDaemonFailureToken?.invalidate()
        ruuviTagHeartbeatDaemonFailureToken?.invalidate()
        ruuviTagReadLogsOperationFailureToken?.invalidate()
    }
    
    // MARK: - Private Methods
    private func observeAdvertisementDaemonFailures() {
        ruuviTagAdvertisementDaemonFailureToken = NotificationCenter.default.addObserver(
            forName: .RuuviTagAdvertisementDaemonDidFail,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let error = userInfo[RuuviTagAdvertisementDaemonDidFailKey.error] as? Error {
                self?.onDaemonError?(error)
            }
        }
    }
    
    private func observePropertiesDaemonFailures() {
        ruuviTagPropertiesDaemonFailureToken = NotificationCenter.default.addObserver(
            forName: .RuuviTagPropertiesDaemonDidFail,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let error = userInfo[RuuviTagPropertiesDaemonDidFailKey.error] as? Error {
                self?.onDaemonError?(error)
            }
        }
    }
    
    private func observeHeartbeatDaemonFailures() {
        ruuviTagHeartbeatDaemonFailureToken = NotificationCenter.default.addObserver(
            forName: .RuuviTagHeartbeatDaemonDidFail,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let error = userInfo[RuuviTagHeartbeatDaemonDidFailKey.error] as? Error {
                self?.onDaemonError?(error)
            }
        }
    }
    
    private func observeReadLogsOperationFailures() {
        ruuviTagReadLogsOperationFailureToken = NotificationCenter.default.addObserver(
            forName: .RuuviTagReadLogsOperationDidFail,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let error = userInfo[RuuviTagReadLogsOperationDidFailKey.error] as? Error {
                self?.onDaemonError?(error)
            }
        }
    }
}

// MARK: - Notification Names and Keys
extension Notification.Name {
    static let RuuviTagAdvertisementDaemonDidFail = Notification.Name("RuuviTagAdvertisementDaemonDidFail")
    static let RuuviTagPropertiesDaemonDidFail = Notification.Name("RuuviTagPropertiesDaemonDidFail")
    static let RuuviTagHeartbeatDaemonDidFail = Notification.Name("RuuviTagHeartbeatDaemonDidFail")
    static let RuuviTagReadLogsOperationDidFail = Notification.Name("RuuviTagReadLogsOperationDidFail")
}

enum RuuviTagAdvertisementDaemonDidFailKey {
    static let error = "error"
}

enum RuuviTagPropertiesDaemonDidFailKey {
    static let error = "error"
}

enum RuuviTagHeartbeatDaemonDidFailKey {
    static let error = "error"
}

enum RuuviTagReadLogsOperationDidFailKey {
    static let error = "error"
}
