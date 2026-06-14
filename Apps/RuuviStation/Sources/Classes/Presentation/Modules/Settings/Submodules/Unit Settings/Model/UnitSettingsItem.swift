import Foundation
import RuuviLocal
import RuuviLocalization
import RuuviOntology

protocol UnitSettingsItemProtocol {
    var title: String { get }
}

enum UnitSettingsMode: Equatable {
    case measurement
    case globalUnits
    case resolution
}

enum ResolutionSettingsTarget: CaseIterable, Equatable, SelectionItemProtocol {
    case temperature
    case relativeHumidity
    case absoluteHumidity
    case dewPoint
    case pressure
    case particulateMatter
    case acceleration
    case voltage

    var title: (String) -> String {
        switch self {
        case .temperature: { _ in RuuviLocalization.temperature }
        case .relativeHumidity: { _ in RuuviLocalization.relativeHumidity }
        case .absoluteHumidity: { _ in RuuviLocalization.absoluteHumidity }
        case .dewPoint: { _ in RuuviLocalization.dewpoint }
        case .pressure: { _ in RuuviLocalization.pressure }
        case .particulateMatter: { _ in RuuviLocalization.pm25 }
        case .acceleration: { _ in RuuviLocalization.acceleration }
        case .voltage: { _ in RuuviLocalization.batteryVoltage }
        }
    }

    var measurementType: MeasurementType {
        switch self {
        case .temperature:
            .temperature
        case .relativeHumidity, .absoluteHumidity, .dewPoint:
            .humidity
        case .pressure:
            .pressure
        case .particulateMatter:
            .pm25
        case .acceleration:
            .accelerationX
        case .voltage:
            .voltage
        }
    }

    func accuracy(
        settings: RuuviLocalSettings,
        pressureUnit: UnitPressure
    ) -> MeasurementAccuracyType {
        switch self {
        case .temperature:
            settings.temperatureAccuracy
        case .relativeHumidity:
            settings.relativeHumidityAccuracy
        case .absoluteHumidity:
            settings.absoluteHumidityAccuracy
        case .dewPoint:
            settings.dewPointAccuracy
        case .pressure:
            pressureUnit.supportsResolutionSelection ? settings.pressureAccuracy : .zero
        case .particulateMatter:
            settings.pmAccuracy
        case .acceleration:
            settings.accelerationAccuracy
        case .voltage:
            settings.voltageAccuracy
        }
    }

    func unitSymbol(
        temperatureUnit: TemperatureUnit,
        pressureUnit: UnitPressure
    ) -> String {
        switch self {
        case .temperature:
            temperatureUnit.symbol
        case .relativeHumidity:
            HumidityUnit.percent.symbol
        case .absoluteHumidity:
            HumidityUnit.gm3.symbol
        case .dewPoint:
            temperatureUnit.symbol
        case .pressure:
            pressureUnit.ruuviSymbol
        case .particulateMatter:
            RuuviLocalization.unitPm25
        case .acceleration:
            RuuviLocalization.g
        case .voltage:
            RuuviLocalization.v
        }
    }
}

struct UnitSettingsViewModel {
    let title: String
    let items: [SelectionItemProtocol]
    let measurementType: MeasurementType
    let mode: UnitSettingsMode

    init(
        title: String,
        items: [SelectionItemProtocol],
        measurementType: MeasurementType,
        mode: UnitSettingsMode = .measurement
    ) {
        self.title = title
        self.items = items
        self.measurementType = measurementType
        self.mode = mode
    }
}
