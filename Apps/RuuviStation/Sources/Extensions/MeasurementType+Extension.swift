import RuuviOntology
import RuuviLocalization
import UIKit

extension MeasurementType {
    static var chartsCases: [MeasurementType] {
        [
            .temperature,
            .anyHumidity,
            .pressure,
            .aqi,
            .co2,
            .pm25,
            .nox,
            .voc,
            .luminosity,
            .soundInstant,
        ]
    }

    static var all: [MeasurementType] {
        [
            .temperature,
            .anyHumidity,
            .pressure,
            .movementCounter,
            .aqi,
            .co2,
            .pm25,
            .pm100,
            .nox,
            .voc,
            .luminosity,
            .soundInstant,
        ]
    }
}

extension MeasurementType {

    /// Returns the Full name for the measurement type
    var fullName: String {
        switch self {
        case .temperature:
            return RuuviLocalization.temperature
        case .humidity(let kind):
            switch kind {
            case .percent:
                return RuuviLocalization.relativeHumidity
            case .gm3:
                return RuuviLocalization.absoluteHumidity
            case .dew:
                return RuuviLocalization.dewpoint
            }
        case .pressure:
            return RuuviLocalization.pressure
        case .movementCounter:
            return RuuviLocalization.movementCounter
        case .aqi:
            return RuuviLocalization.airQuality
        case .co2:
            return RuuviLocalization.carbonDioxide
        case .pm25:
            return RuuviLocalization.particulateMatter25
        case .pm100:
            return RuuviLocalization.particulateMatter100
        case .nox:
            return RuuviLocalization.nitrogenOxides
        case .voc:
            return RuuviLocalization.volatileOrganicCompounds
        case .soundInstant:
            return RuuviLocalization.soundInstant
        case .luminosity:
            return RuuviLocalization.illuminance
        default:
            return ""
        }
    }

    /// Returns the Short name for the measurement type
    var shortName: String {
        switch self {
        case .temperature:
            return RuuviLocalization.temperature
        case .humidity(let kind):
            switch kind {
            case .percent:
                return RuuviLocalization.relHumidity
            case .gm3:
                return RuuviLocalization.absHumidity
            case .dew:
                return RuuviLocalization.dewpoint
            }
        case .pressure:
            return RuuviLocalization.pressure
        case .movementCounter:
            return RuuviLocalization.movements
        case .aqi:
            return RuuviLocalization.airQuality
        case .co2:
            return RuuviLocalization.co2
        case .pm25:
            return RuuviLocalization.pm25
        case .pm100:
            return RuuviLocalization.pm100
        case .nox:
            return RuuviLocalization.nox
        case .voc:
            return RuuviLocalization.voc
        case .soundInstant:
            return RuuviLocalization.soundInstant
        case .luminosity:
            return RuuviLocalization.light
        default:
            return ""
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
        case .pm100:
            return RuuviAsset.Measurements.iconPm10.image
        case .nox:
            return RuuviAsset.Measurements.iconNox.image
        case .voc:
            return RuuviAsset.Measurements.iconVoc.image
        case .soundInstant:
            return RuuviAsset.Measurements.iconSoundInstant.image
        case .luminosity:
            return RuuviAsset.Measurements.iconLuminosity.image
        default:
            return RuuviAsset.Measurements.iconMeasurements.image
        }
    }

    var descriptionText: String {
        switch self {
        case .temperature:
            return RuuviLocalization.descriptionTextTemperatureCelsius
        case .humidity:
            return RuuviLocalization.descriptionTextHumidityRelative
        case .pressure:
            return RuuviLocalization.descriptionTextPressure
        case .movementCounter:
            return RuuviLocalization.descriptionTextMovement
        case .aqi:
            return RuuviLocalization.descriptionTextAirQuality
        case .co2:
            return RuuviLocalization.descriptionTextCo2
        case .pm25, .pm100:
            return RuuviLocalization.descriptionTextPm
        case .nox:
            return RuuviLocalization.descriptionTextNox
        case .voc:
            return RuuviLocalization.descriptionTextVoc
        case .soundInstant:
            return RuuviLocalization.descriptionTextSoundLevel
        case .luminosity:
            return RuuviLocalization.descriptionTextLuminosity
        default:
            return ""
        }
    }
}

extension MeasurementType {
    // swiftlint:disable:next cyclomatic_complexity
    func toAlertType() -> AlertType {
        switch self {
        case .aqi:
            return .aqi(lower: 0, upper: 0)
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
            return .pMatter25(lower: 0, upper: 0)
        case .pm100:
            return .pMatter10(lower: 0, upper: 0)
        case .nox:
            return .nox(lower: 0, upper: 0)
        case .voc:
            return .voc(lower: 0, upper: 0)
        case .soundInstant:
            return .soundInstant(lower: 0, upper: 0)
        case .luminosity:
            return .luminosity(lower: 0, upper: 0)
        default:
            return .temperature(lower: 0, upper: 0)
        }
    }
}

extension MeasurementType {
    static func hideUnit(for type: MeasurementType) -> Bool {
        switch type {
        case .aqi, .voc, .nox, .movementCounter:
            return true
        default:
            return false
        }
    }
}

extension MeasurementType {
    static var anyHumidity: MeasurementType { .humidity(.percent) }
}

extension MeasurementType {
  /// Same enum case ignoring associated values.
  func isSameCase(as other: MeasurementType) -> Bool {
    switch (self, other) {
    case (.aqi, .aqi), (.co2, .co2), (.pm25, .pm25), (.pm100, .pm100),
         (.voc, .voc), (.nox, .nox),
         (.temperature, .temperature),
         (.humidity, .humidity),
         (.pressure, .pressure),
         (.luminosity, .luminosity),
         (.movementCounter, .movementCounter),
         (.soundInstant, .soundInstant):
      return true
    default:
      return false
    }
  }
}

extension Array where Element == MeasurementType {
  func firstIndexMatchingCase(of probe: MeasurementType) -> Int? {
    firstIndex { $0.isSameCase(as: probe) }
  }
}
