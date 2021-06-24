import Foundation
import BTKit
import RuuviOntology
import RuuviVirtual

protocol RuuviServiceNotifier {
    func process(heartbeat ruuviTag: RuuviTagSensorRecord)
    func process(data: VirtualData, for sensor: VirtualSensor)
    func processNetwork(record: RuuviTagSensorRecord, for identifier: MACIdentifier)

    func subscribe<T: RuuviServiceNotifierObserver>(_ observer: T, to uuid: String)
    func isSubscribed<T: RuuviServiceNotifierObserver>(_ observer: T, to uuid: String) -> Bool
}

protocol RuuviServiceNotifierObserver: AnyObject {
    func ruuviNotifier(service: RuuviServiceNotifier, isTriggered: Bool, for uuid: String)
}
