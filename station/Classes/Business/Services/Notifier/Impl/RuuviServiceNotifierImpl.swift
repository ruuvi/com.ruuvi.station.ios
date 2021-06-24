import Foundation
import BTKit
import RuuviOntology
import RuuviService
import RuuviNotification

class RuuviServiceNotifierImpl: RuuviServiceNotifier {
    var ruuviAlertService: RuuviServiceAlert!
    weak var localNotificationsManager: RuuviNotificationLocal!

    var observations = [String: NSPointerArray]()

    func subscribe<T: RuuviServiceNotifierObserver>(_ observer: T, to uuid: String) {
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

    func isSubscribed<T: RuuviServiceNotifierObserver>(_ observer: T, to uuid: String) -> Bool {
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
