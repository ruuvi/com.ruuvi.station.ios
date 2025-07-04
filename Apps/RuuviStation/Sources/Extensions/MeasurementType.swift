import RuuviOntology
import RuuviLocalization
import UIKit

enum MeasurementType: String {
    case rssi
    case temperature
    case humidity
    case pressure
    // v3 & v5
    case acceleration
    case voltage
    // v5
    case movementCounter
    case txPower
    // E0/F0
    case aqi
    case co2
    case pm25
    case pm10
    case nox
    case voc
    case luminosity
    case sound
}

extension MeasurementType {
    static var chartsCases: [MeasurementType] {
        [
            .temperature,
            .humidity,
            .pressure,
            .aqi,
            .co2,
            .pm25,
            .pm10,
            .nox,
            .voc,
            .luminosity,
            .sound,
        ]
    }

    static var all: [MeasurementType] {
        [
            .temperature,
            .humidity,
            .pressure,
            .movementCounter,
            .aqi,
            .co2,
            .pm25,
            .pm10,
            .nox,
            .voc,
            .luminosity,
            .sound,
        ]
    }
}

extension MeasurementType {

    /// Returns the display name for the measurement type
    var displayName: String {
        switch self {
        case .temperature:
            return RuuviLocalization.temperature
        case .humidity:
            return RuuviLocalization.humidity
        case .pressure:
            return RuuviLocalization.pressure
        case .movementCounter:
            return RuuviLocalization.movementCounter
        case .aqi:
            return RuuviLocalization.airQuality
        case .co2:
            return RuuviLocalization.co2
        case .pm25:
            return RuuviLocalization.pm25
        case .pm10:
            return RuuviLocalization.pm10
        case .nox:
            return RuuviLocalization.nox
        case .voc:
            return RuuviLocalization.voc
        case .sound:
            return RuuviLocalization.soundAvg
        case .luminosity:
            return RuuviLocalization.luminosity
        default:
            return rawValue.capitalized
        }
    }

    /// Returns the icon for the measurement type
    var icon: UIImage {
        switch self {
        case .temperature:
            return RuuviAsset.Measurements.iconTemperature.image
        case .humidity:
            return RuuviAsset.Measurements.iconHumidity.image
        case .pressure:
            return RuuviAsset.Measurements.iconPressure.image
        case .movementCounter:
            return RuuviAsset.Measurements.iconMovement.image
        case .aqi:
            return RuuviAsset.Measurements.iconAqi.image
        case .co2:
            return RuuviAsset.Measurements.iconCo2.image
        case .pm25:
            return RuuviAsset.Measurements.iconPm25.image
        case .pm10:
            return RuuviAsset.Measurements.iconPm10.image
        case .nox:
            return RuuviAsset.Measurements.iconNox.image
        case .voc:
            return RuuviAsset.Measurements.iconVoc.image
        case .sound:
            return RuuviAsset.Measurements.iconSoundLevel.image
        case .luminosity:
            return RuuviAsset.Measurements.iconLuminosity.image
        default:
            return RuuviAsset.Measurements.iconMeasurements.image
        }
    }

}

extension MeasurementType {
    // swiftlint:disable:next cyclomatic_complexity
    func toAlertType() -> AlertType {
        switch self {
        case .temperature:
            return .temperature(lower: 0, upper: 0)
        case .humidity:
            return .relativeHumidity(lower: 0, upper: 0)
        case .pressure:
            return .pressure(lower: 0, upper: 0)
        case .movementCounter:
            return .movement(last: 0)
        case .co2:
            return .carbonDioxide(lower: 0, upper: 0)
        case .pm25:
            return .pMatter2_5(lower: 0, upper: 0)
        case .pm10:
            return .pMatter10(lower: 0, upper: 0)
        case .nox:
            return .nox(lower: 0, upper: 0)
        case .voc:
            return .voc(lower: 0, upper: 0)
        case .sound:
            return .sound(lower: 0, upper: 0)
        case .luminosity:
            return .luminosity(lower: 0, upper: 0)
        default:
            return .temperature(lower: 0, upper: 0)
        }
    }
}
