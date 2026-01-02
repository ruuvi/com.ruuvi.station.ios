// swiftlint:disable file_length

import RuuviOntology
import RuuviLocalization
import UIKit
import RuuviLocal

extension MeasurementType {

    /// Returns the Full name for the measurement type
    var fullName: String {
        fullName(for: nil)
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func fullName(for variant: MeasurementDisplayVariant?) -> String {
        switch self {
        case .temperature:
            return RuuviLocalization.temperature
        case .humidity:
            let resolvedUnit = variant?.humidityUnit ?? .percent
            switch resolvedUnit {
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
        case .voltage:
            return RuuviLocalization.battery
        case .rssi:
            return RuuviLocalization.signalStrength
        case .accelerationX:
            return RuuviLocalization.TagSettings.AccelerationXTitleLabel.text
        case .accelerationY:
            return RuuviLocalization.TagSettings.AccelerationYTitleLabel.text
        case .accelerationZ:
            return RuuviLocalization.TagSettings.AccelerationZTitleLabel.text
        case .aqi:
            return RuuviLocalization.airQuality
        case .co2:
            return RuuviLocalization.carbonDioxide
        case .pm10:
            return RuuviLocalization.pm10
        case .pm25:
            return RuuviLocalization.particulateMatter25
        case .pm40:
            return RuuviLocalization.pm40
        case .pm100:
            return RuuviLocalization.particulateMatter100
        case .nox:
            return RuuviLocalization.nitrogenOxides
        case .voc:
            return RuuviLocalization.volatileOrganicCompounds
        case .soundInstant:
            return RuuviLocalization.soundInstant
        case .soundAverage:
            return RuuviLocalization.soundAvg
        case .soundPeak:
            return RuuviLocalization.soundPeak
        case .luminosity:
            return RuuviLocalization.illuminance
        case .measurementSequenceNumber:
            return RuuviLocalization.TagSettings.MsnTitleLabel.text
        default:
            return ""
        }
    }

    /// Returns the Short name for the measurement type
    var shortName: String {
        shortName(for: nil)
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func shortName(for variant: MeasurementDisplayVariant?) -> String {
        switch self {
        case .temperature:
            return RuuviLocalization.temperature
        case .humidity:
            let resolvedUnit = variant?.humidityUnit ?? .percent
            switch resolvedUnit {
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
        case .voltage:
            return RuuviLocalization.battery
        case .rssi:
            return RuuviLocalization.signalStrength
        case .accelerationX:
            return RuuviLocalization.accX
        case .accelerationY:
            return RuuviLocalization.accY
        case .accelerationZ:
            return RuuviLocalization.accZ
        case .aqi:
            return RuuviLocalization.airQuality
        case .co2:
            return RuuviLocalization.co2
        case .pm10:
            return RuuviLocalization.pm10
        case .pm25:
            return RuuviLocalization.pm25
        case .pm40:
            return RuuviLocalization.pm40
        case .pm100:
            return RuuviLocalization.pm100
        case .nox:
            return RuuviLocalization.nox
        case .voc:
            return RuuviLocalization.voc
        case .soundInstant:
            return RuuviLocalization.soundInstant
        case .soundAverage:
            return RuuviLocalization.soundAvg
        case .soundPeak:
            return RuuviLocalization.soundPeak
        case .luminosity:
            return RuuviLocalization.light
        case .measurementSequenceNumber:
            return RuuviLocalization.measSeqNumber
        default:
            return ""
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func shortNameWithUnit(for variant: MeasurementDisplayVariant?) -> String {
        switch self {
        case .temperature:
            let unit = variant?.temperatureUnit ?? .celsius
            return RuuviLocalization.temperatureWithUnit(unit.symbol)
        case .humidity:
            let shortName = shortName(for: variant)
            let temperatureUnit = variant?.temperatureUnit ?? .celsius
            let unit = variant?.humidityUnit ?? .percent
            if unit == .dew {
                return shortName + " (\(temperatureUnit.symbol))"
            } else {
                return shortName + " (\(unit.symbol))"
            }
        case .pressure:
            let unit = variant?.pressureUnit ?? .hectopascals
            return RuuviLocalization.pressureWithUnit(unit.ruuviSymbol)
        case .movementCounter:
            return RuuviLocalization.movements
        case .voltage:
            return RuuviLocalization.battery + " (\(RuuviLocalization.v))"
        case .accelerationX:
            return RuuviLocalization.accX + " (\(RuuviLocalization.g))"
        case .accelerationY:
            return RuuviLocalization.accY + " (\(RuuviLocalization.g))"
        case .accelerationZ:
            return RuuviLocalization.accZ + " (\(RuuviLocalization.g))"
        case .aqi:
            return RuuviLocalization.airQuality
        case .co2:
            return RuuviLocalization.co2WithUnit(RuuviLocalization.unitCo2)
        case .pm10:
            return RuuviLocalization.pm10WithUnit(RuuviLocalization.unitPm10)
        case .pm25:
            return RuuviLocalization.pm25WithUnit(RuuviLocalization.unitPm25)
        case .pm40:
            return RuuviLocalization.pm40WithUnit(RuuviLocalization.unitPm40)
        case .pm100:
            return RuuviLocalization.pm100WithUnit(RuuviLocalization.unitPm100)
        case .voc:
            return RuuviLocalization.vocWithUnit(RuuviLocalization.unitVoc)
        case .nox:
            return RuuviLocalization.noxWithUnit(RuuviLocalization.unitNox)
        case .soundInstant:
            return RuuviLocalization.soundInstantWithUnit(RuuviLocalization.unitSound)
        case .soundAverage:
            return RuuviLocalization.soundAverageWithUnit(RuuviLocalization.unitSound)
        case .soundPeak:
            return RuuviLocalization.soundPeakWithUnit(RuuviLocalization.unitSound)
        case .luminosity:
            return RuuviLocalization.luminosityWithUnit(RuuviLocalization.unitLuminosity)
        case .rssi:
            return RuuviLocalization.signalStrengthWithUnit()
        default:
            return shortName(for: variant)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func unit(
        for variant: MeasurementDisplayVariant,
        settings: RuuviLocalSettings
    ) -> String {
        switch variant.type {
        case .temperature:
            let unit = variant.temperatureUnit ?? settings.temperatureUnit
            return unit.symbol
        case .humidity:
            switch variant.resolvedHumidityUnit(default: settings.humidityUnit) {
            case .percent:
                return RuuviLocalization.humidityRelativeUnit
            case .gm3:
                return RuuviLocalization.gm³
            case .dew:
                let tempUnit = variant.temperatureUnit ?? settings.temperatureUnit
                return tempUnit.symbol
            }
        case .pressure:
            let pressureUnit = variant.resolvedPressureUnit(default: settings.pressureUnit)
            return pressureUnit.ruuviSymbol
        case .co2:
            return RuuviLocalization.unitCo2
        case .pm10:
            return RuuviLocalization.unitPm10
        case .pm25:
            return RuuviLocalization.unitPm25
        case .pm40:
            return RuuviLocalization.unitPm40
        case .pm100:
            return RuuviLocalization.unitPm100
        case .voc:
            return RuuviLocalization.unitVoc
        case .nox:
            return RuuviLocalization.unitNox
        case .luminosity:
            return RuuviLocalization.unitLuminosity
        case .soundInstant:
            return RuuviLocalization.unitSound
        case .voltage:
            return RuuviLocalization.v
        case .rssi:
            return RuuviLocalization.dBm
        case .accelerationX, .accelerationY, .accelerationZ:
            return RuuviLocalization.g
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
        case .pm10:
            return RuuviAsset.Measurements.iconPm1.image
        case .pm25:
            return RuuviAsset.Measurements.iconPm25.image
        case .pm40:
            return RuuviAsset.Measurements.iconPm4.image
        case .pm100:
            return RuuviAsset.Measurements.iconPm10.image
        case .nox:
            return RuuviAsset.Measurements.iconNox.image
        case .voc:
            return RuuviAsset.Measurements.iconVoc.image
        case .soundInstant:
            return RuuviAsset.Measurements.iconSoundInstant.image
        case .soundAverage:
            return RuuviAsset.Measurements.iconSoundAverage.image
        case .soundPeak:
            return RuuviAsset.Measurements.iconSoundPeak.image
        case .luminosity:
            return RuuviAsset.Measurements.iconLuminosity.image
        case .voltage:
            return RuuviAsset.Measurements.iconBatteryLevel.image
        case .rssi:
            return RuuviAsset.Measurements.iconSignalStrength.image
        case .accelerationX:
            return RuuviAsset.Measurements.iconAccelerationX.image
        case .accelerationY:
            return RuuviAsset.Measurements.iconAccelerationY.image
        case .accelerationZ:
            return RuuviAsset.Measurements.iconAccelerationZ.image
        default:
            return RuuviAsset.Measurements.iconMeasurements.image
        }
    }

    var descriptionText: String {
        descriptionText(for: nil)
    }

    // swiftlint:disable:next cyclomatic_complexity
    func descriptionText(for variant: MeasurementDisplayVariant?) -> String {
        switch self {
        case .temperature:
            switch variant?.temperatureUnit ?? .celsius {
            case .celsius:
                return RuuviLocalization.descriptionTextTemperatureCelsius
            case .fahrenheit:
                return RuuviLocalization.descriptionTextTemperatureFahrenheit
            case .kelvin:
                return RuuviLocalization.descriptionTextTemperatureKelvin
            }
        case .humidity:
            let resolvedUnit = variant?.humidityUnit ?? .percent
            switch resolvedUnit {
            case .percent:
                return RuuviLocalization.descriptionTextHumidityRelative
            case .gm3:
                return RuuviLocalization.descriptionTextHumidityAbsolute
            case .dew:
                return RuuviLocalization.descriptionTextHumidityDewpoint
            }
        case .pressure:
            return RuuviLocalization.descriptionTextPressure
        case .movementCounter:
            return RuuviLocalization.descriptionTextMovement
        case .voltage:
            return RuuviLocalization.descriptionTextBatteryVoltage
        case .rssi:
            return RuuviLocalization.descriptionTextSignalStrength
        case .accelerationX, .accelerationY, .accelerationZ:
            return RuuviLocalization.descriptionTextAcceleration
        case .measurementSequenceNumber:
            return RuuviLocalization.descriptionTextMeasurementSequenceNumber
        case .aqi:
            return RuuviLocalization.descriptionTextAirQuality
        case .co2:
            return RuuviLocalization.descriptionTextCo2
        case .pm10, .pm25, .pm40, .pm100:
            return RuuviLocalization.descriptionTextPm
        case .nox:
            return RuuviLocalization.descriptionTextNox
        case .voc:
            return RuuviLocalization.descriptionTextVoc
        case .soundInstant, .soundAverage, .soundPeak:
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
    func toAlertType() -> AlertType? {
        switch self {
        case .aqi:
            return .aqi(lower: 0, upper: 0)
        case .temperature:
            return .temperature(lower: 0, upper: 0)
        case .humidity:
            return .relativeHumidity(lower: 0, upper: 0)
        case .voltage:
            return .batteryVoltage(lower: 0, upper: 0)
        case .pressure:
            return .pressure(lower: 0, upper: 0)
        case .movementCounter:
            return .movement(last: 0)
        case .co2:
            return .carbonDioxide(lower: 0, upper: 0)
        case .pm10:
            return .pMatter1(lower: 0, upper: 0)
        case .pm25:
            return .pMatter25(lower: 0, upper: 0)
        case .pm40:
            return .pMatter4(lower: 0, upper: 0)
        case .pm100:
            return .pMatter10(lower: 0, upper: 0)
        case .nox:
            return .nox(lower: 0, upper: 0)
        case .voc:
            return .voc(lower: 0, upper: 0)
        case .soundInstant:
            return .soundInstant(lower: 0, upper: 0)
        case .soundPeak:
            return .soundPeak(lower: 0, upper: 0)
        case .soundAverage:
            return .soundAverage(lower: 0, upper: 0)
        case .luminosity:
            return .luminosity(lower: 0, upper: 0)
        case .rssi:
            return .signal(lower: 0, upper: 0)
        default:
            return nil
        }
    }
}

extension MeasurementDisplayVariant {
    func toAlertType() -> AlertType? {
        switch type {
        case .humidity:
            switch humidityUnit {
            case .gm3:
                return .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute)
            case .dew:
                return .dewPoint(lower: 0, upper: 0)
            case .percent, .none:
                return .relativeHumidity(lower: 0, upper: 0)
            }
        case .voltage:
            return .batteryVoltage(lower: 0, upper: 0)
        default:
            return type.toAlertType()
        }
    }
}

extension MeasurementType {
    static func hideUnit(for type: MeasurementType) -> Bool {
        switch type {
        case .aqi, .voc, .nox, .movementCounter, .measurementSequenceNumber:
            return true
        default:
            return false
        }
    }
}

extension MeasurementType {
  /// Same enum case ignoring associated values.
    func isSameCase(as other: MeasurementType) -> Bool {
    switch (self, other) {
    case (.aqi, .aqi),
         (.co2, .co2),
         (.pm10, .pm10),
         (.pm25, .pm25),
         (.pm40, .pm40),
         (.pm100, .pm100),
         (.voc, .voc),
         (.nox, .nox),
         (.temperature, .temperature),
         (.humidity, .humidity),
         (.pressure, .pressure),
         (.luminosity, .luminosity),
         (.movementCounter, .movementCounter),
         (.soundInstant, .soundInstant),
         (.soundAverage, .soundAverage),
         (.soundPeak, .soundPeak),
         (.voltage, .voltage),
         (.txPower, .txPower),
         (.rssi, .rssi),
         (.accelerationX, .accelerationX),
         (.accelerationY, .accelerationY),
         (.accelerationZ, .accelerationZ),
         (.measurementSequenceNumber, .measurementSequenceNumber):
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
// swiftlint:enable file_length
