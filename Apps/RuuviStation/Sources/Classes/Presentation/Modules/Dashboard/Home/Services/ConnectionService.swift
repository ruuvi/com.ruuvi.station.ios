import Foundation
import BTKit
import CoreBluetooth
import RuuviOntology
import RuuviLocal

protocol ConnectionServiceProtocol: AnyObject {
    var bluetoothState: BTScannerState { get }
    var connectionStatus: [String: Bool] { get }
    var rssiReadings: [String: Int] { get }
    
    var onBluetoothStateChanged: ((BTScannerState) -> Void)? { get set }
    var onConnectionStatusChanged: (([String: Bool]) -> Void)? { get set }
    var onRSSIUpdated: (([String: Int]) -> Void)? { get set }
    
    func startObservingConnections()
    func stopObservingConnections()
    func isConnected(uuid: String) -> Bool
    func setKeepConnection(_ keepConnection: Bool, for luid: LocalIdentifier)
}

final class ConnectionService: ConnectionServiceProtocol {
    // MARK: - Dependencies
    private let background: BTBackground
    private let foreground: BTForeground
    private let connectionPersistence: RuuviLocalConnections
    
    // MARK: - Private Properties
    private var _bluetoothState: BTScannerState = .unknown
    private var _connectionStatus: [String: Bool] = [:]
    private var _rssiReadings: [String: Int] = [:]
    
    private var stateToken: ObservationToken?
    private var didConnectToken: NSObjectProtocol?
    private var didDisconnectToken: NSObjectProtocol?
    private var readRSSIToken: NSObjectProtocol?
    private var readRSSIIntervalToken: NSObjectProtocol?
    
    // MARK: - Public Properties
    var bluetoothState: BTScannerState {
        return _bluetoothState
    }
    
    var connectionStatus: [String: Bool] {
        return _connectionStatus
    }
    
    var rssiReadings: [String: Int] {
        return _rssiReadings
    }
    
    var onBluetoothStateChanged: ((BTScannerState) -> Void)?
    var onConnectionStatusChanged: (([String: Bool]) -> Void)?
    var onRSSIUpdated: (([String: Int]) -> Void)?
    
    // MARK: - Initialization
    init(
        background: BTBackground,
        foreground: BTForeground,
        connectionPersistence: RuuviLocalConnections
    ) {
        self.background = background
        self.foreground = foreground
        self.connectionPersistence = connectionPersistence
    }
    
    deinit {
        stopObservingConnections()
    }
    
    // MARK: - Public Methods
    func startObservingConnections() {
        observeBluetoothState()
        observeConnectionChanges()
        observeRSSIUpdates()
    }
    
    func stopObservingConnections() {
        stateToken?.invalidate()
        didConnectToken?.invalidate()
        didDisconnectToken?.invalidate()
        readRSSIToken?.invalidate()
        readRSSIIntervalToken?.invalidate()
    }
    
    func isConnected(uuid: String) -> Bool {
        return background.isConnected(uuid: uuid)
    }
    
    func setKeepConnection(_ keepConnection: Bool, for luid: LocalIdentifier) {
        connectionPersistence.setKeepConnection(keepConnection, for: luid)
    }
    
    // MARK: - Private Methods
    private func observeBluetoothState() {
        stateToken = foreground.state(self) { [weak self] observer, state in
            guard let self = self else { return }
            self._bluetoothState = state
            self.onBluetoothStateChanged?(state)
        }
    }
    
    private func observeConnectionChanges() {
        didConnectToken = NotificationCenter.default.addObserver(
            forName: .BTBackgroundDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleConnectionChange(notification, isConnected: true)
        }
        
        didDisconnectToken = NotificationCenter.default.addObserver(
            forName: .BTBackgroundDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleConnectionChange(notification, isConnected: false)
        }
    }
    
    private func observeRSSIUpdates() {
        readRSSIToken = NotificationCenter.default.addObserver(
            forName: .BTBackgroundDidUpdateRSSI,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRSSIUpdate(notification)
        }
        
        readRSSIIntervalToken = NotificationCenter.default.addObserver(
            forName: .RSSIReadIntervalDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Handle RSSI read interval changes if needed
        }
    }
    
    private func handleConnectionChange(_ notification: Notification, isConnected: Bool) {
        guard let uuid = notification.userInfo?["uuid"] as? String else { return }
        
        _connectionStatus[uuid] = isConnected
        onConnectionStatusChanged?(_connectionStatus)
    }
    
    private func handleRSSIUpdate(_ notification: Notification) {
        guard let uuid = notification.userInfo?["uuid"] as? String,
              let rssi = notification.userInfo?["rssi"] as? Int else { return }
        
        _rssiReadings[uuid] = rssi
        onRSSIUpdated?(_rssiReadings)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let BTBackgroundDidConnect = Notification.Name("BTBackgroundDidConnect")
    static let BTBackgroundDidDisconnect = Notification.Name("BTBackgroundDidDisconnect")
    static let BTBackgroundDidUpdateRSSI = Notification.Name("BTBackgroundDidUpdateRSSI")
    static let RSSIReadIntervalDidChange = Notification.Name("RSSIReadIntervalDidChange")
}
