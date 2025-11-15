import RuuviOntology

public enum RuuviCloudSensorVisibilityCode: String, CaseIterable, Codable {
    case temperatureC = "TEMPERATURE_C"
    case temperatureF = "TEMPERATURE_F"
    case temperatureK = "TEMPERATURE_K"

    case humidityRelative = "HUMIDITY_0"
    case humidityAbsolute = "HUMIDITY_1"
    case humidityDewPoint = "HUMIDITY_2"

    case pressureLegacyPa = "PRESSURE_0"
    case pressureHectopascal = "PRESSURE_1"
    case pressureMillimeterMercury = "PRESSURE_2"
    case pressureInchMercury = "PRESSURE_3"

    case movementCount = "MOVEMENT_COUNT"
    case batteryVoltage = "BATTERY_VOLT"
    case accelerationGX = "ACCELERATION_GX"
    case accelerationGY = "ACCELERATION_GY"
    case accelerationGZ = "ACCELERATION_GZ"
    case signalDbm = "SIGNAL_DBM"

    case aqiIndex = "AQI_INDEX"
    case luminosityLux = "LUMINOSITY_LX"
    case soundAverage = "SOUNDAVG_DBA"
    case soundPeak = "SOUNDPEAK_SPL"
    case soundInstant = "SOUNDINSTANT_SPL"

    case co2ppm = "CO2_PPM"
    case vocIndex = "VOC_INDEX"
    case noxIndex = "NOX_INDEX"
    case pm10 = "PM10_MGM3"
    case pm25 = "PM25_MGM3"
    case pm40 = "PM40_MGM3"
    case pm100 = "PM100_MGM3"

    public var variant: MeasurementDisplayVariant {
        switch self {
        case .temperatureC:
            return MeasurementDisplayVariant(type: .temperature, temperatureUnit: .celsius)
        case .temperatureF:
            return MeasurementDisplayVariant(type: .temperature, temperatureUnit: .fahrenheit)
        case .temperatureK:
            return MeasurementDisplayVariant(type: .temperature, temperatureUnit: .kelvin)

        case .humidityRelative:
            return MeasurementDisplayVariant(type: .humidity, humidityUnit: .percent)
        case .humidityAbsolute:
            return MeasurementDisplayVariant(type: .humidity, humidityUnit: .gm3)
        case .humidityDewPoint:
            return MeasurementDisplayVariant(type: .humidity, humidityUnit: .dew)

        case .pressureLegacyPa, .pressureHectopascal:
            return MeasurementDisplayVariant(type: .pressure, pressureUnit: .hectopascals)
        case .pressureMillimeterMercury:
            return MeasurementDisplayVariant(type: .pressure, pressureUnit: .millimetersOfMercury)
        case .pressureInchMercury:
            return MeasurementDisplayVariant(type: .pressure, pressureUnit: .inchesOfMercury)

        case .movementCount:
            return MeasurementDisplayVariant(type: .movementCounter)
        case .batteryVoltage:
            return MeasurementDisplayVariant(type: .voltage)
        case .accelerationGX:
            return MeasurementDisplayVariant(type: .accelerationX)
        case .accelerationGY:
            return MeasurementDisplayVariant(type: .accelerationY)
        case .accelerationGZ:
            return MeasurementDisplayVariant(type: .accelerationZ)
        case .signalDbm:
            return MeasurementDisplayVariant(type: .rssi)

        case .aqiIndex:
            return MeasurementDisplayVariant(type: .aqi)
        case .luminosityLux:
            return MeasurementDisplayVariant(type: .luminosity)
        case .soundAverage:
            return MeasurementDisplayVariant(type: .soundAverage)
        case .soundPeak:
            return MeasurementDisplayVariant(type: .soundPeak)
        case .soundInstant:
            return MeasurementDisplayVariant(type: .soundInstant)

        case .co2ppm:
            return MeasurementDisplayVariant(type: .co2)
        case .vocIndex:
            return MeasurementDisplayVariant(type: .voc)
        case .noxIndex:
            return MeasurementDisplayVariant(type: .nox)
        case .pm10:
            return MeasurementDisplayVariant(type: .pm10)
        case .pm25:
            return MeasurementDisplayVariant(type: .pm25)
        case .pm40:
            return MeasurementDisplayVariant(type: .pm40)
        case .pm100:
            return MeasurementDisplayVariant(type: .pm100)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public init?(variant: MeasurementDisplayVariant) {
        switch variant.type {
        case .temperature:
            let unit = variant.temperatureUnit ?? .celsius
            switch unit {
            case .fahrenheit:
                self = .temperatureF
            case .kelvin:
                self = .temperatureK
            default:
                self = .temperatureC
            }
        case .humidity:
            let unit = variant.humidityUnit ?? .percent
            switch unit {
            case .gm3:
                self = .humidityAbsolute
            case .dew:
                self = .humidityDewPoint
            default:
                self = .humidityRelative
            }
        case .pressure:
            let unit = variant.pressureUnit ?? .hectopascals
            switch unit {
            case .millimetersOfMercury:
                self = .pressureMillimeterMercury
            case .inchesOfMercury:
                self = .pressureInchMercury
            default:
                self = .pressureHectopascal
            }
        case .movementCounter:
            self = .movementCount
        case .voltage:
            self = .batteryVoltage
        case .accelerationX:
            self = .accelerationGX
        case .accelerationY:
            self = .accelerationGY
        case .accelerationZ:
            self = .accelerationGZ
        case .rssi:
            self = .signalDbm
        case .aqi:
            self = .aqiIndex
        case .luminosity:
            self = .luminosityLux
        case .soundAverage:
            self = .soundAverage
        case .soundPeak:
            self = .soundPeak
        case .soundInstant:
            self = .soundInstant
        case .co2:
            self = .co2ppm
        case .voc:
            self = .vocIndex
        case .nox:
            self = .noxIndex
        case .pm10:
            self = .pm10
        case .pm25:
            self = .pm25
        case .pm40:
            self = .pm40
        case .pm100:
            self = .pm100
        default:
            return nil
        }
    }

    public static func parse(_ rawValue: String) -> RuuviCloudSensorVisibilityCode? {
        Self(rawValue: rawValue.uppercased())
    }
}

public extension MeasurementDisplayVariant {
    var cloudVisibilityCode: RuuviCloudSensorVisibilityCode? {
        RuuviCloudSensorVisibilityCode(variant: self)
    }
}
