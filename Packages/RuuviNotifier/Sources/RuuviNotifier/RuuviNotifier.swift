import Foundation
import RuuviOntology

public protocol RuuviNotifier {
    func process(record ruuviTag: RuuviTagSensorRecord, trigger: Bool)
    func processNetwork(record: RuuviTagSensorRecord, trigger: Bool, for identifier: MACIdentifier)

    func subscribe<T: RuuviNotifierObserver>(_ observer: T, to uuid: String)
    func isSubscribed<T: RuuviNotifierObserver>(_ observer: T, to uuid: String) -> Bool
    func clearMovementHysteresis(for uuid: String)
}

public protocol RuuviNotifierObserver: AnyObject {
    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String)
    // Optional method
    func ruuvi(
        notifier: RuuviNotifier,
        alertType: AlertType,
        isTriggered: Bool,
        for uuid: String
    )
}

public extension RuuviNotifierObserver {
    // Optional method implementation
    func ruuvi(
        notifier _: RuuviNotifier,
        alertType _: AlertType,
        isTriggered _: Bool,
        for _: String
    ) {}
}

public extension RuuviNotifier {
    func clearMovementAlertHysteresis(for _: String) {}
}

public protocol RuuviNotifierTitles {
    func lowTemperature(_ value: String) -> String
    func highTemperature(_ value: String) -> String
    func lowHumidity(_ value: String) -> String
    func highHumidity(_ value: String) -> String
    func lowAbsoluteHumidity(_ value: String) -> String
    func highAbsoluteHumidity(_ value: String) -> String
    func lowDewPoint(_ value: String) -> String
    func highDewPoint(_ value: String) -> String
    func lowPressure(_ value: String) -> String
    func highPressure(_ value: String) -> String
    func lowSignal(_ value: String) -> String
    func highSignal(_ value: String) -> String
    func lowAQI(_ value: String) -> String
    func highAQI(_ value: String) -> String
    func lowCarbonDioxide(_ value: String) -> String
    func highCarbonDioxide(_ value: String) -> String
    func lowPMatter1(_ value: String) -> String
    func highPMatter1(_ value: String) -> String
    func lowPMatter25(_ value: String) -> String
    func highPMatter25(_ value: String) -> String
    func lowPMatter4(_ value: String) -> String
    func highPMatter4(_ value: String) -> String
    func lowPMatter10(_ value: String) -> String
    func highPMatter10(_ value: String) -> String
    func lowVOC(_ value: String) -> String
    func highVOC(_ value: String) -> String
    func lowNOx(_ value: String) -> String
    func highNOx(_ value: String) -> String
    func lowSoundInstant(_ value: String) -> String
    func highSoundInstant(_ value: String) -> String
    func lowSoundAverage(_ value: String) -> String
    func highSoundAverage(_ value: String) -> String
    func lowSoundPeak(_ value: String) -> String
    func highSoundPeak(_ value: String) -> String
    func lowLuminosity(_ value: String) -> String
    func highLuminosity(_ value: String) -> String
    func lowBatteryVoltage(_ value: String) -> String
    func highBatteryVoltage(_ value: String) -> String

    var didMove: String { get }
}
