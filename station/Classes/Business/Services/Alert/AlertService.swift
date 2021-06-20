import Foundation
import BTKit
import RuuviOntology
import RuuviVirtual

protocol AlertService {
    func process(heartbeat ruuviTag: RuuviTagSensorRecord)
    func process(data: VirtualData, for sensor: VirtualSensor)
    func processNetwork(record: RuuviTagSensorRecord, for identifier: MACIdentifier)

    func subscribe<T: AlertServiceObserver>(_ observer: T, to uuid: String)
    func isSubscribed<T: AlertServiceObserver>(_ observer: T, to uuid: String) -> Bool
}

protocol AlertServiceObserver: AnyObject {
    func alert(service: AlertService, isTriggered: Bool, for uuid: String)
}
