import Foundation
import RuuviLocal
import RuuviNotification
import RuuviNotifier
import RuuviOntology
import RuuviService

public final class RuuviNotifierImpl: RuuviNotifier {
    var observations = [String: NSPointerArray]()
    let titles: RuuviNotifierTitles
    let ruuviAlertService: RuuviServiceAlert
    let localNotificationsManager: RuuviNotificationLocal
    let localSyncState: RuuviLocalSyncState

    public init(
        ruuviAlertService: RuuviServiceAlert,
        ruuviNotificationLocal: RuuviNotificationLocal,
        localSyncState: RuuviLocalSyncState,
        titles: RuuviNotifierTitles
    ) {
        self.ruuviAlertService = ruuviAlertService
        localNotificationsManager = ruuviNotificationLocal
        self.localSyncState = localSyncState
        self.titles = titles
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
}
