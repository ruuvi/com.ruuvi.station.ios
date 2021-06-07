import Foundation
import BTKit
import RuuviOntology

protocol AlertService {
    func process(heartbeat ruuviTag: RuuviTagSensorRecord)
    func process(data: WPSData, for uuid: String)
    func processNetwork(record: RuuviTagSensorRecord, for identifier: MACIdentifier)

    func subscribe<T: AlertServiceObserver>(_ observer: T, to uuid: String)
    func isSubscribed<T: AlertServiceObserver>(_ observer: T, to uuid: String) -> Bool
}

protocol AlertServiceObserver: AnyObject {
    func alert(service: AlertService, isTriggered: Bool, for uuid: String)
}
