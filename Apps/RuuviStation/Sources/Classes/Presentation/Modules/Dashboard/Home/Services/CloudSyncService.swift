import Foundation
import RuuviDaemon
import RuuviService
import RuuviLocal
import RuuviUser
import RuuviOntology

protocol CloudSyncServiceProtocol: AnyObject {
    var cloudMode: Bool { get }
    var syncStatus: CloudSyncStatus { get }
    
    var onCloudModeChanged: ((Bool) -> Void)? { get set }
    var onSyncStatusChanged: ((CloudSyncStatus) -> Void)? { get set }
    
    func startObservingCloudSync()
    func stopObservingCloudSync()
    func triggerFullHistorySync()
    func refreshImmediately()
    func getSyncStatus(for macId: MACIdentifier) -> NetworkSyncStatus?
}

enum CloudSyncStatus {
    case idle
    case syncing
    case success
    case failure(Error)
}

final class CloudSyncService: CloudSyncServiceProtocol {
    // MARK: - Dependencies
    private let cloudSyncDaemon: RuuviDaemonCloudSync
    private let cloudSyncService: RuuviServiceCloudSync
    private let localSyncState: RuuviLocalSyncState
    private let ruuviUser: RuuviUser
    private let settings: RuuviLocalSettings
    
    // MARK: - Private Properties
    private var _cloudMode: Bool = false
    private var _syncStatus: CloudSyncStatus = .idle
    
    private var cloudModeToken: NSObjectProtocol?
    private var cloudSyncSuccessStateToken: NSObjectProtocol?
    private var cloudSyncFailStateToken: NSObjectProtocol?
    
    // MARK: - Public Properties
    var cloudMode: Bool {
        return _cloudMode
    }
    
    var syncStatus: CloudSyncStatus {
        return _syncStatus
    }
    
    var onCloudModeChanged: ((Bool) -> Void)?
    var onSyncStatusChanged: ((CloudSyncStatus) -> Void)?
    
    // MARK: - Initialization
    init(
        cloudSyncDaemon: RuuviDaemonCloudSync,
        cloudSyncService: RuuviServiceCloudSync,
        localSyncState: RuuviLocalSyncState,
        ruuviUser: RuuviUser,
        settings: RuuviLocalSettings
    ) {
        self.cloudSyncDaemon = cloudSyncDaemon
        self.cloudSyncService = cloudSyncService
        self.localSyncState = localSyncState
        self.ruuviUser = ruuviUser
        self.settings = settings
        
        // Initialize cloud mode state
        _cloudMode = settings.cloudModeEnabled
    }
    
    deinit {
        stopObservingCloudSync()
    }
    
    // MARK: - Public Methods
    func startObservingCloudSync() {
        observeCloudModeChanges()
        observeCloudSyncStates()
    }
    
    func stopObservingCloudSync() {
        cloudModeToken?.invalidate()
        cloudSyncSuccessStateToken?.invalidate()
        cloudSyncFailStateToken?.invalidate()
    }
    
    func triggerFullHistorySync() {
        guard ruuviUser.isAuthorized else { return }
        
        _syncStatus = .syncing
        onSyncStatusChanged?(_syncStatus)
        
        Task {
            do {
                try await cloudSyncService.syncAll()
                await MainActor.run {
                    self._syncStatus = .success
                    self.onSyncStatusChanged?(self._syncStatus)
                }
            } catch {
                await MainActor.run {
                    self._syncStatus = .failure(error)
                    self.onSyncStatusChanged?(self._syncStatus)
                }
            }
        }
    }
    
    func refreshImmediately() {
        cloudSyncDaemon.refreshImmediately()
        _syncStatus = .syncing
        onSyncStatusChanged?(_syncStatus)
    }
    
    func getSyncStatus(for macId: MACIdentifier) -> NetworkSyncStatus? {
        return localSyncState.getSyncStatusLatestRecord(for: macId)
    }
    
    // MARK: - Private Methods
    private func observeCloudModeChanges() {
        cloudModeToken = NotificationCenter.default.addObserver(
            forName: .CloudModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let isCloudModeEnabled = self.settings.cloudModeEnabled
            self._cloudMode = isCloudModeEnabled
            self.onCloudModeChanged?(isCloudModeEnabled)
            
            if isCloudModeEnabled && self.ruuviUser.isAuthorized {
                self.triggerFullHistorySync()
            }
        }
    }
    
    private func observeCloudSyncStates() {
        cloudSyncSuccessStateToken = NotificationCenter.default.addObserver(
            forName: .CloudSyncDidSucceed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self._syncStatus = .success
            self.onSyncStatusChanged?(self._syncStatus)
        }
        
        cloudSyncFailStateToken = NotificationCenter.default.addObserver(
            forName: .CloudSyncDidFail,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let error = notification.userInfo?["error"] as? Error ?? 
                       CloudSyncError.unknownError
            self._syncStatus = .failure(error)
            self.onSyncStatusChanged?(self._syncStatus)
        }
    }
}

// MARK: - CloudSyncError
enum CloudSyncError: Error, LocalizedError {
    case unknownError
    case networkError
    case authenticationError
    
    var errorDescription: String? {
        switch self {
        case .unknownError:
            return "Unknown cloud sync error"
        case .networkError:
            return "Network connection error"
        case .authenticationError:
            return "Authentication error"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let CloudModeDidChange = Notification.Name("CloudModeDidChange")
    static let CloudSyncDidSucceed = Notification.Name("CloudSyncDidSucceed")
    static let CloudSyncDidFail = Notification.Name("CloudSyncDidFail")
}
