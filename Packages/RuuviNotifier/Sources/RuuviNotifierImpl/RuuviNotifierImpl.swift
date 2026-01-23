import Foundation
import RuuviLocal
import RuuviNotification
import RuuviOntology
import RuuviService

public final class RuuviNotifierImpl: RuuviNotifier {
    var observations = [String: NSPointerArray]()
    let titles: RuuviNotifierTitles
    let ruuviAlertService: RuuviServiceAlert
    let localNotificationsManager: RuuviNotificationLocal
    let localSyncState: RuuviLocalSyncState
    let measurementService: RuuviServiceMeasurement
    let settings: RuuviLocalSettings
    /// State isolated to main thread - all access must be on main queue
    @MainActor var movementAlertHysteresisLastEventByUUID = [String: Date]()
    var movementAlertHysteresisTimer: Timer?
    private var alertDidChangeToken: NSObjectProtocol?

    /// Synchronously access the hysteresis state on main thread
    func withHysteresisState<T>(_ block: @MainActor () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { block() }
        } else {
            return DispatchQueue.main.sync {
                MainActor.assumeIsolated { block() }
            }
        }
    }

    public init(
        ruuviAlertService: RuuviServiceAlert,
        ruuviNotificationLocal: RuuviNotificationLocal,
        localSyncState: RuuviLocalSyncState,
        measurementService: RuuviServiceMeasurement,
        settings: RuuviLocalSettings,
        titles: RuuviNotifierTitles
    ) {
        self.ruuviAlertService = ruuviAlertService
        localNotificationsManager = ruuviNotificationLocal
        self.localSyncState = localSyncState
        self.titles = titles
        self.measurementService = measurementService
        self.settings = settings
        restoreMovementHysteresisState()
        startObservingAlertChanges()
    }

    deinit {
        movementAlertHysteresisTimer?.invalidate()
        if let alertDidChangeToken {
            NotificationCenter.default.removeObserver(alertDidChangeToken)
        }
    }

    public func subscribe(_ observer: some RuuviNotifierObserver, to uuid: String) {
        guard !isSubscribed(observer, to: uuid) else { return }
        let pointer = Unmanaged.passUnretained(observer).toOpaque()
        if let array = observations[uuid] {
            array.addPointer(pointer)
            array.compact()
        } else {
            let array = NSPointerArray.weakObjects()
            array.addPointer(pointer)
            observations[uuid] = array
            array.compact()
        }
    }

    public func isSubscribed(_ observer: some RuuviNotifierObserver, to uuid: String) -> Bool {
        let observerPointer = Unmanaged.passUnretained(observer).toOpaque()
        if let array = observations[uuid] {
            for i in 0 ..< array.count {
                let pointer = array.pointer(at: i)
                if pointer == observerPointer {
                    return true
                }
            }
            return false
        } else {
            return false
        }
    }

    private func startObservingAlertChanges() {
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviServiceAlertDidChange,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }
                guard let userInfo = notification.userInfo,
                      let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType,
                      let physicalSensor = userInfo[
                          RuuviServiceAlertDidChangeKey.physicalSensor
                      ] as? PhysicalSensor
                else {
                    return
                }
                guard case .movement = type else { return }
                let isOn = self.ruuviAlertService.isOn(type: type, for: physicalSensor)
                guard !isOn else { return }
                guard let uuid = physicalSensor.luid?.value ?? physicalSensor.macId?.value else {
                    return
                }
                self.clearMovementAlertHysteresis(for: uuid)
            }
    }
}
