import Foundation
import RuuviOntology
import RuuviService
import RuuviNotification

public final class RuuviServiceNotifierImpl: RuuviServiceNotifier {
    var observations = [String: NSPointerArray]()
    let titles: RuuviServiceNotifierTitles
    let ruuviAlertService: RuuviServiceAlert
    let localNotificationsManager: RuuviNotificationLocal

    public init(
        ruuviAlertService: RuuviServiceAlert,
        ruuviNotificationLocal: RuuviNotificationLocal,
        titles: RuuviServiceNotifierTitles
    ) {
        self.ruuviAlertService = ruuviAlertService
        self.localNotificationsManager = ruuviNotificationLocal
        self.titles = titles
    }

    public func subscribe<T: RuuviServiceNotifierObserver>(_ observer: T, to uuid: String) {
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

    public func isSubscribed<T: RuuviServiceNotifierObserver>(_ observer: T, to uuid: String) -> Bool {
        let observerPointer = Unmanaged.passUnretained(observer).toOpaque()
        if let array = observations[uuid] {
            for i in 0..<array.count {
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
