// swiftlint:disable file_length

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
    private var notificationTokens: [NSObjectProtocol] = []

    // MARK: - State
    // swiftlint:disable:next large_tuple
    private typealias SnapshotConnectionUpdate = (
        snapshot: RuuviTagCardSnapshot,
        isConnected: Bool,
        keepConnection: Bool,
        syncStatus: NetworkSyncStatus
    )

    private let trackedSnapshotsQueue = DispatchQueue(label: "RuuviTagConnectionService.trackedSnapshotsQueue")
    private var trackedSnapshots: [RuuviTagCardSnapshot] = []

    private var isBluetoothPermissionGranted: Bool {
        let centralAuthorization = CBManager.authorization
        if centralAuthorization == .denied || centralAuthorization == .restricted {
            return false
        }

        let peripheralStatus = CBManager.authorization
        switch peripheralStatus {
        case .denied, .restricted:
            return false
        default:
            return true
        }
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
        resetNotificationObservers()
        observeConnectionEvents()
        observeConnectionPersistenceEvents()
    }

    func stopObservingConnections() {
        stateToken?.invalidate()
        resetNotificationObservers()

        stateToken = nil
    }

    func refreshBluetoothState() {
        notifyBluetoothStateChange(foreground.bluetoothState)
    }

    func updateConnectionData(for snapshots: [RuuviTagCardSnapshot]) {
        updateTrackedSnapshots(snapshots)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let snapshotUpdates = snapshots.map { self.connectionUpdate(for: $0) }
            DispatchQueue.main.async {
                snapshotUpdates.forEach { self.apply($0) }
            }
        }
    }

    func updateConnectionData(for snapshot: RuuviTagCardSnapshot) {
        updateTrackedSnapshot(snapshot)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let snapshotUpdate = self.connectionUpdate(for: snapshot)
            DispatchQueue.main.async {
                self.apply(snapshotUpdate)
            }
        }
    }

    func setKeepConnection(
        _ keep: Bool,
        for snapshot: RuuviTagCardSnapshot
    ) {
        guard let luid = snapshot.identifierData.luid else { return }

        connectionPersistence.setKeepConnection(keep, for: luid)

        let didChange = snapshot.updateConnectionData(
            isConnected: snapshot.connectionData.isConnected,
            isConnectable: snapshot.connectionData.isConnectable,
            keepConnection: keep
        )

        if didChange {
            delegate?.connectionService(self, didUpdateSnapshot: snapshot)
        }
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
            observer.notifyBluetoothStateChange(state)
        }
        notifyBluetoothStateChange(foreground.bluetoothState)
    }

    func observeConnectionEvents() {
        notificationTokens.append(observeUUID(
            forName: .BTBackgroundDidConnect,
            key: BTBackgroundDidConnectKey.uuid
        ) { [weak self] uuid in
            self?.handleConnectionChange(uuid: uuid, isConnected: true)
        })

        notificationTokens.append(observeUUID(
            forName: .BTBackgroundDidDisconnect,
            key: BTBackgroundDidDisconnectKey.uuid
        ) { [weak self] uuid in
            self?.handleConnectionChange(uuid: uuid, isConnected: false)
        })
    }

    func observeConnectionPersistenceEvents() {
        notificationTokens.append(observeUUID(
            forName: .ConnectionPersistenceDidStartToKeepConnection,
            key: CPDidStartToKeepConnectionKey.uuid
        ) { [weak self] uuid in
            self?.refreshConnectionState(uuid: uuid)
        })

        notificationTokens.append(observeUUID(
            forName: .ConnectionPersistenceDidStopToKeepConnection,
            key: CPDidStopToKeepConnectionKey.uuid
        ) { [weak self] uuid in
            self?.refreshConnectionState(uuid: uuid)
        })
    }

    func resetNotificationObservers() {
        notificationTokens.forEach { $0.invalidate() }
        notificationTokens.removeAll()
    }

    func observeUUID<Key: Hashable>(
        forName name: Notification.Name,
        key: Key,
        handler: @escaping (String) -> Void
    ) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { notification in
            guard let uuid = notification.userInfo?[AnyHashable(key)] as? String else { return }
            handler(uuid)
        }
    }

    func notifyBluetoothStateChange(_ state: BTScannerState) {
        let resolvedState = resolvedBluetoothState(for: state)
        if resolvedState.userDeclined || !resolvedState.isEnabled {
            delegate?.connectionService(
                self,
                bluetoothStateChanged: resolvedState.isEnabled,
                userDeclined: resolvedState.userDeclined
            )
        }
    }

    func handleConnectionChange(uuid: String, isConnected: Bool) {
        updateConnectionState(uuid: uuid, isConnected: isConnected)

        NotificationCenter.default.post(
            name: .DashboardConnectionDidChange,
            object: nil,
            userInfo: [
                "uuid": uuid,
                "isConnected": isConnected,
            ]
        )
    }

    func resolvedBluetoothState(for state: BTScannerState) -> (isEnabled: Bool, userDeclined: Bool) {
        let permissionDenied = !isBluetoothPermissionGranted || state == .unauthorized

        if permissionDenied {
            let isEnabled = state == .poweredOn
            return (isEnabled, true)
        }

        switch state {
        case .poweredOff,
             .unsupported:
            return (false, false)
        default:
            return (true, false)
        }
    }

    func updateTrackedSnapshots(_ snapshots: [RuuviTagCardSnapshot]) {
        trackedSnapshotsQueue.sync {
            trackedSnapshots = snapshots
        }
    }

    func updateTrackedSnapshot(_ snapshot: RuuviTagCardSnapshot) {
        trackedSnapshotsQueue.sync {
            if let index = trackedSnapshots.firstIndex(where: { trackedSnapshot in
                let sameLuid = snapshot.identifierData.luid?.any != nil &&
                    trackedSnapshot.identifierData.luid?.any == snapshot.identifierData.luid?.any
                let sameMac = snapshot.identifierData.mac?.any != nil &&
                    trackedSnapshot.identifierData.mac?.any == snapshot.identifierData.mac?.any
                return trackedSnapshot.id == snapshot.id || sameLuid || sameMac
            }) {
                trackedSnapshots[index] = snapshot
            } else {
                trackedSnapshots.append(snapshot)
            }
        }
    }

    func snapshot(for uuid: String) -> RuuviTagCardSnapshot? {
        trackedSnapshotsQueue.sync {
            trackedSnapshots.first { $0.identifierData.luid?.value == uuid }
        }
    }

    func updateConnectionState(uuid: String, isConnected: Bool) {
        guard let snapshot = snapshot(for: uuid) else { return }

        let keepConnection = snapshot.identifierData.luid.map {
            connectionPersistence.keepConnection(to: $0)
        } ?? snapshot.connectionData.keepConnection

        let didChange = snapshot.updateConnectionData(
            isConnected: isConnected,
            isConnectable: snapshot.connectionData.isConnectable,
            keepConnection: keepConnection
        )

        if didChange {
            delegate?.connectionService(self, didUpdateSnapshot: snapshot)
        }
    }

    func refreshConnectionState(uuid: String) {
        updateConnectionState(
            uuid: uuid,
            isConnected: background.isConnected(uuid: uuid)
        )
    }

    private func connectionUpdate(for snapshot: RuuviTagCardSnapshot) -> SnapshotConnectionUpdate {
        var isConnected = false
        var keepConnection = false
        var syncStatus: NetworkSyncStatus = .none
        if let luid = snapshot.identifierData.luid {
            isConnected = background.isConnected(uuid: luid.value)
            keepConnection = connectionPersistence.keepConnection(to: luid)
        } else if snapshot.identifierData.mac != nil {
            syncStatus = snapshot.identifierData.mac.map {
                localSyncState.getSyncStatusLatestRecord(for: $0)
            } ?? .none
        }
        return (snapshot, isConnected, keepConnection, syncStatus)
    }

    private func apply(_ update: SnapshotConnectionUpdate) {
        let statusChanged = update.snapshot.updateNetworkSyncStatus(update.syncStatus)
        let connectionChanged = update.snapshot.updateConnectionData(
            isConnected: update.isConnected,
            isConnectable: update.snapshot.connectionData.isConnectable,
            keepConnection: update.keepConnection
        )
        if statusChanged || connectionChanged {
            delegate?.connectionService(self, didUpdateSnapshot: update.snapshot)
        }
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
            if snapshot.updateNetworkSyncStatus(syncStatus) {
                self.delegate?.connectionService(self, didUpdateSnapshot: snapshot)
            }
        }
    }
}

// MARK: - Bluetooth Management
extension RuuviTagConnectionService {

    func getCurrentBluetoothState() -> (isEnabled: Bool, userDeclined: Bool) {
        resolvedBluetoothState(for: foreground.bluetoothState)
    }

    func requestBluetoothPermissionIfNeeded() -> Bool {
        return isBluetoothPermissionGranted
    }

    func shouldShowBluetoothAlert(for snapshots: [RuuviTagCardSnapshot]) -> Bool {
        let hasBluetoothSensors = hasBluetoothSensors(in: snapshots)
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

// swiftlint:enable file_length
