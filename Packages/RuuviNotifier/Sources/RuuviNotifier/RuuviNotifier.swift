import Foundation
import RuuviOntology
import RuuviVirtual

public protocol RuuviNotifier {
    func process(record ruuviTag: RuuviTagSensorRecord, trigger: Bool)
    func process(data: VirtualData, for sensor: VirtualSensor)
    func processNetwork(record: RuuviTagSensorRecord, trigger: Bool, for identifier: MACIdentifier)

    func subscribe<T: RuuviNotifierObserver>(_ observer: T, to uuid: String)
    func isSubscribed<T: RuuviNotifierObserver>(_ observer: T, to uuid: String) -> Bool
}

public protocol RuuviNotifierObserver: AnyObject {
    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String)
    // Optional method
    func ruuvi(notifier: RuuviNotifier,
               alertType: AlertType,
               isTriggered: Bool,
               for uuid: String)
}

extension RuuviNotifierObserver {
    // Optional method implementation
    public func ruuvi(notifier: RuuviNotifier,
                      alertType: AlertType,
                      isTriggered: Bool,
                      for uuid: String) {}
}

public protocol RuuviNotifierTitles {
    var lowTemperature: String { get }
    var highTemperature: String { get }
    var lowHumidity: String { get }
    var highHumidity: String { get }
    var lowDewPoint: String { get }
    var highDewPoint: String { get }
    var lowPressure: String { get }
    var highPressure: String { get }
    var didMove: String { get }
}
