import Foundation
import CoreBluetooth
import BTKit
import RuuviOntology
import RuuviLocal

protocol RuuviTagConnectionServiceDelegate: AnyObject {
    func connectionService(
        _ service: RuuviTagConnectionService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot
    )
    func connectionService(
        _ service: RuuviTagConnectionService,
        bluetoothStateChanged isEnabled: Bool,
        userDeclined: Bool
    )
    func connectionService(
        _ service: RuuviTagConnectionService,
        didEncounterError error: Error
    )
}

class RuuviTagConnectionService {

    // MARK: - Dependencies
    private let foreground: BTForeground
    private let background: BTBackground
    private let connectionPersistence: RuuviLocalConnections
    private let localSyncState: RuuviLocalSyncState

    // MARK: - Properties
    weak var delegate: RuuviTagConnectionServiceDelegate?

    // MARK: - Observation Tokens
    private var stateToken: ObservationToken?
    private var didConnectToken: NSObjectProtocol?
    private var didDisconnectToken: NSObjectProtocol?

    // MARK: - State
    private var isBluetoothPermissionGranted: Bool {
        CBCentralManager.authorization == .allowedAlways
    }

    // MARK: - Initialization
    init(
        foreground: BTForeground,
        background: BTBackground,
        connectionPersistence: RuuviLocalConnections,
        localSyncState: RuuviLocalSyncState
    ) {
        self.foreground = foreground
        self.background = background
        self.connectionPersistence = connectionPersistence
        self.localSyncState = localSyncState
    }

    deinit {
        stopObservingConnections()
    }

    // MARK: - Public Interface
    func startObservingConnections() {
        observeBluetoothState()
        observeConnectionEvents()
    }

    func stopObservingConnections() {
        stateToken?.invalidate()
        didConnectToken?.invalidate()
        didDisconnectToken?.invalidate()

        stateToken = nil
        didConnectToken = nil
        didDisconnectToken = nil
    }

    func updateConnectionData(for snapshots: [RuuviTagCardSnapshot]) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // swiftlint:disable:next large_tuple
            var snapshotUpdates: [(RuuviTagCardSnapshot, Bool, Bool, NetworkSyncStatus)] = []

            for snapshot in snapshots {
                var isConnected = false
                var keepConnection = false
                var syncStatus: NetworkSyncStatus = .none

                if let luid = snapshot.identifierData.luid {
                    isConnected = self.background.isConnected(uuid: luid.value)
                    keepConnection = self.connectionPersistence.keepConnection(to: luid)
                } else if snapshot.identifierData.mac != nil {
                    syncStatus = snapshot.identifierData.mac.map {
                        self.localSyncState.getSyncStatusLatestRecord(for: $0)
                    } ?? .none
                    isConnected = false
                    keepConnection = false
                }

                snapshotUpdates.append((snapshot, isConnected, keepConnection, syncStatus))
            }

            DispatchQueue.main.async {
                for (snapshot, isConnected, keepConnection, syncStatus) in snapshotUpdates {
                    snapshot.updateNetworkSyncStatus(syncStatus)
                    snapshot.updateConnectionData(
                        isConnected: isConnected,
                        isConnectable: snapshot.connectionData.isConnectable,
                        keepConnection: keepConnection
                    )
                    self.delegate?.connectionService(self, didUpdateSnapshot: snapshot)
                }
            }
        }
    }

    func setKeepConnection(
        _ keep: Bool,
        for snapshot: RuuviTagCardSnapshot
    ) {
        guard let luid = snapshot.identifierData.luid else { return }

        connectionPersistence.setKeepConnection(keep, for: luid)

        snapshot.updateConnectionData(
            isConnected: snapshot.connectionData.isConnected,
            isConnectable: snapshot.connectionData.isConnectable,
            keepConnection: keep
        )

        delegate?.connectionService(self, didUpdateSnapshot: snapshot)
    }

    func getConnectionStatus(
        for snapshot: RuuviTagCardSnapshot
    ) -> (isConnected: Bool, keepConnection: Bool) {
        guard let luid = snapshot.identifierData.luid else {
            return (false, false)
        }

        let isConnected = background.isConnected(uuid: luid.value)
        let keepConnection = connectionPersistence.keepConnection(to: luid)

        return (isConnected, keepConnection)
    }

    func removeConnectionsForCloudSensors(snapshots: [RuuviTagCardSnapshot]) {
        let cloudConnections = connectionPersistence.keepConnectionUUIDs.filter { luid in
            snapshots.filter(\.metadata.isCloud).contains { snapshot in
                snapshot.identifierData.luid?.any == luid
            }
        }

        for luid in cloudConnections {
            connectionPersistence.setKeepConnection(false, for: luid)
        }
    }

    func hasBluetoothSensors(in snapshots: [RuuviTagCardSnapshot]) -> Bool {
        return snapshots.contains { !$0.metadata.isCloud }
    }
}

// MARK: - Private Implementation
private extension RuuviTagConnectionService {

    func observeBluetoothState() {
        stateToken?.invalidate()
        stateToken = foreground.state(self) { observer, state in
            let isEnabled = state == .poweredOn
            let userDeclined = !observer.isBluetoothPermissionGranted

            if !isEnabled || userDeclined {
                observer.delegate?.connectionService(
                    observer,
                    bluetoothStateChanged: isEnabled,
                    userDeclined: userDeclined
                )
            }
        }
    }

    func observeConnectionEvents() {
        // Observe connection events
        didConnectToken?.invalidate()
        didConnectToken = NotificationCenter.default.addObserver(
            forName: .BTBackgroundDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let userInfo = notification.userInfo,
               let uuid = userInfo[BTBackgroundDidConnectKey.uuid] as? String {
                self.handleConnectionChange(uuid: uuid, isConnected: true)
            }
        }

        // Observe disconnection events
        didDisconnectToken?.invalidate()
        didDisconnectToken = NotificationCenter.default.addObserver(
            forName: .BTBackgroundDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            if let userInfo = notification.userInfo,
               let uuid = userInfo[BTBackgroundDidDisconnectKey.uuid] as? String {
                self.handleConnectionChange(uuid: uuid, isConnected: false)
            }
        }
    }

    func handleConnectionChange(uuid: String, isConnected: Bool) {
        // Notify delegate about connection change for specific sensor
        // The delegate should update the appropriate snapshot
        NotificationCenter.default.post(
            name: .DashboardConnectionDidChange,
            object: nil,
            userInfo: [
                "uuid": uuid,
                "isConnected": isConnected,
            ]
        )
    }
}

// MARK: - Network Sync Status
extension RuuviTagConnectionService {

    func updateNetworkSyncStatus(for snapshots: [RuuviTagCardSnapshot]) {
        for snapshot in snapshots {
            updateNetworkSyncStatus(for: snapshot)
        }
    }

    func updateNetworkSyncStatus(for snapshot: RuuviTagCardSnapshot) {
        guard let macId = snapshot.identifierData.mac,
              !snapshot.metadata.isCloud else { return }

        let syncStatus = localSyncState.getSyncStatusLatestRecord(for: macId)

        DispatchQueue.main.async {
            snapshot.updateNetworkSyncStatus(syncStatus)
            self.delegate?.connectionService(self, didUpdateSnapshot: snapshot)
        }
    }
}

// MARK: - Bluetooth Management
extension RuuviTagConnectionService {

    func getCurrentBluetoothState() -> (isEnabled: Bool, userDeclined: Bool) {
        let isEnabled = foreground.bluetoothState == .poweredOn
        let userDeclined = !isBluetoothPermissionGranted
        return (isEnabled, userDeclined)
    }

    func requestBluetoothPermissionIfNeeded() -> Bool {
        return isBluetoothPermissionGranted
    }

    func shouldShowBluetoothAlert(for snapshots: [RuuviTagCardSnapshot]) -> Bool {
        let hasBluetoothSensors = self.hasBluetoothSensors(in: snapshots)
        let (isEnabled, userDeclined) = getCurrentBluetoothState()

        return hasBluetoothSensors && (!isEnabled || userDeclined)
    }
}

// MARK: - Connection Utilities
extension RuuviTagConnectionService {

    func getKeepConnectionUUIDs() -> [LocalIdentifier] {
        return connectionPersistence.keepConnectionUUIDs
    }

    func clearAllConnections() {
        for uuid in connectionPersistence.keepConnectionUUIDs {
            connectionPersistence.setKeepConnection(false, for: uuid)
        }
    }

    func getConnectionStatistics() -> (connected: Int, keepConnection: Int) {
        let keepConnectionUUIDs = connectionPersistence.keepConnectionUUIDs
        let connectedCount = keepConnectionUUIDs.filter { uuid in
            background.isConnected(uuid: uuid.value)
        }.count

        return (connectedCount, keepConnectionUUIDs.count)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let DashboardConnectionDidChange = Notification.Name("DashboardConnectionDidChange")
}
