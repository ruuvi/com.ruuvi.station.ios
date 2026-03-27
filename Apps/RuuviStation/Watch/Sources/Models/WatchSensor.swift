import Foundation

struct WatchSensor: Identifiable, Equatable {
    let id: String
    let name: String
    let version: Int?
    let temperature: Double?
    let humidity: Double?
    let pressure: Double?
    let voltage: Double?
    let txPower: Int?
    let accelerationX: Double?
    let accelerationY: Double?
    let accelerationZ: Double?
    let movementCounter: Int?
    let measurementSequenceNumber: Int?
    let rssi: Int?
    let pm1: Double?
    let pm25: Double?
    let pm4: Double?
    let pm10: Double?
    let co2: Double?
    let voc: Double?
    let nox: Double?
    let luminosity: Double?
    let soundInstant: Double?
    let soundAverage: Double?
    let soundPeak: Double?
    let updatedAt: Date?
    let displayOrderCodes: [String]
    let defaultDisplayOrder: Bool

    var displayName: String {
        name.isEmpty ? id : name
    }

    func displayItems(appGroupDefaults: UserDefaults?) -> [SensorMeasurementItem] {
        let preferences = DisplayPreferences(defaults: appGroupDefaults)
        return resolvedDisplayCodes(using: preferences).compactMap {
            item(for: $0, preferences: preferences)
        }
    }

    func formattedUpdatedAt() -> String {
        guard let date = updatedAt else { return "--" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = .autoupdatingCurrent
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private extension WatchSensor {
    var isAirSensor: Bool {
        if let version, version == 0xE1 || version == 0x06 {
            return true
        }

        return [
            pm1,
            pm25,
            pm4,
            pm10,
            co2,
            voc,
            nox,
            luminosity,
            soundInstant,
            soundAverage,
            soundPeak,
        ]
        .contains { $0 != nil }
    }

    func resolvedDisplayCodes(using preferences: DisplayPreferences) -> [DisplayCode] {
        let availableCodes = orderedAvailableCodes()
        let customCodes = uniqueCodes(
            displayOrderCodes.compactMap(DisplayCode.init(rawCode:))
        )
        let supportedCustomCodes = customCodes.filter(availableCodes.contains)

        if !defaultDisplayOrder {
            if !customCodes.isEmpty {
                return supportedCustomCodes.isEmpty ? availableCodes : supportedCustomCodes
            }

            let visibleDefaults = availableCodes.filter {
                isDefaultVisible($0, using: preferences)
            }
            return visibleDefaults.isEmpty ? availableCodes : visibleDefaults
        }

        let preferredSet = Set(supportedCustomCodes)
        let visibleCodes = availableCodes.filter { code in
            isDefaultVisible(code, using: preferences) || preferredSet.contains(code)
        }
        return visibleCodes.isEmpty ? availableCodes : visibleCodes
    }

    func orderedAvailableCodes() -> [DisplayCode] {
        if isAirSensor {
            return [
                .aqiIndex,
                .co2ppm,
                .pm25,
                .vocIndex,
                .noxIndex,
                .temperatureC,
                .temperatureF,
                .temperatureK,
                .humidityRelative,
                .humidityAbsolute,
                .humidityDewPoint,
                .pressurePa,
                .pressureHectopascal,
                .pressureMillimeterMercury,
                .pressureInchMercury,
                .luminosityLux,
                .soundInstantSpl,
                .soundAverage,
                .soundPeak,
                .pm10,
                .pm40,
                .pm100,
                .measurementSequenceNumber,
                .signalDbm,
            ]
        }

        return [
            .temperatureC,
            .temperatureF,
            .temperatureK,
            .humidityRelative,
            .humidityAbsolute,
            .humidityDewPoint,
            .pressurePa,
            .pressureHectopascal,
            .pressureMillimeterMercury,
            .pressureInchMercury,
            .movementCount,
            .measurementSequenceNumber,
            .batteryVoltage,
            .accelerationGX,
            .accelerationGY,
            .accelerationGZ,
            .signalDbm,
        ]
    }

    func isDefaultVisible(
        _ code: DisplayCode,
        using preferences: DisplayPreferences
    ) -> Bool {
        switch code {
        case .temperatureC,
             .temperatureF,
             .temperatureK:
            return code == preferences.temperatureCode
        case .humidityRelative,
             .humidityAbsolute,
             .humidityDewPoint:
            return code == preferences.humidityCode
        case .pressurePa,
             .pressureHectopascal,
             .pressureMillimeterMercury,
             .pressureInchMercury:
            return code == preferences.pressureCode
        case .pm10,
             .pm40,
             .pm100,
             .measurementSequenceNumber,
             .soundAverage,
             .soundPeak,
             .batteryVoltage,
             .signalDbm,
             .accelerationGX,
             .accelerationGY,
             .accelerationGZ:
            return false
        default:
            return true
        }
    }

    func uniqueCodes(_ codes: [DisplayCode]) -> [DisplayCode] {
        var seen = Set<DisplayCode>()
        return codes.filter { seen.insert($0).inserted }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func item(
        for code: DisplayCode,
        preferences: DisplayPreferences
    ) -> SensorMeasurementItem? {
        switch code {
        case .temperatureC:
            guard let value = temperature else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFixed(value, digits: preferences.temperatureAccuracy.decimals),
                unit: "°C",
                label: "Temperature"
            )
        case .temperatureF:
            guard let value = temperature else { return nil }
            let converted = (value * 9 / 5) + 32
            return measurementItem(
                code: code,
                value: preferences.formatFixed(converted, digits: preferences.temperatureAccuracy.decimals),
                unit: "°F",
                label: "Temperature"
            )
        case .temperatureK:
            guard let value = temperature else { return nil }
            let converted = value + 273.15
            return measurementItem(
                code: code,
                value: preferences.formatFixed(converted, digits: preferences.temperatureAccuracy.decimals),
                unit: "K",
                label: "Temperature"
            )
        case .humidityRelative:
            guard let value = humidity else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFixed(value, digits: preferences.humidityAccuracy.decimals),
                unit: "%",
                label: "Rel. humidity"
            )
        case .humidityAbsolute:
            guard let humidity, let temperature else { return nil }
            let absolute = absoluteHumidity(relativeHumidity: humidity, temperatureCelsius: temperature)
            return measurementItem(
                code: code,
                value: preferences.formatFixed(absolute, digits: preferences.humidityAccuracy.decimals),
                unit: "g/m³",
                label: "Abs. humidity"
            )
        case .humidityDewPoint:
            guard let humidity, let temperature else { return nil }
            let valueCelsius = dewPoint(relativeHumidity: humidity, temperatureCelsius: temperature)
            let converted = preferences.temperatureUnit.convertFromCelsius(valueCelsius)
            return measurementItem(
                code: code,
                value: preferences.formatFixed(converted, digits: preferences.humidityAccuracy.decimals),
                unit: preferences.temperatureUnit.symbol,
                label: "Dew point"
            )
        case .pressurePa:
            guard let pressure else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFixed(pressure * 100.0, digits: 0),
                unit: "Pa",
                label: "Pressure"
            )
        case .pressureHectopascal:
            guard let pressure else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFixed(pressure, digits: preferences.pressureAccuracy.digits(for: .hectopascals)),
                unit: "hPa",
                label: "Pressure"
            )
        case .pressureMillimeterMercury:
            guard let pressure else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFixed(
                    pressure * 0.750061683,
                    digits: preferences.pressureAccuracy.digits(for: .millimetersOfMercury)
                ),
                unit: "mmHg",
                label: "Pressure"
            )
        case .pressureInchMercury:
            guard let pressure else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFixed(
                    pressure * 0.029529983,
                    digits: preferences.pressureAccuracy.digits(for: .inchesOfMercury)
                ),
                unit: "inHg",
                label: "Pressure"
            )
        case .movementCount:
            guard let movementCounter else { return nil }
            return measurementItem(
                code: code,
                value: "\(movementCounter)",
                unit: "",
                label: "Movements"
            )
        case .batteryVoltage:
            guard let voltage else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(voltage),
                unit: "V",
                label: "Battery"
            )
        case .accelerationGX:
            guard let accelerationX else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(accelerationX),
                unit: "g",
                label: "Acc. X"
            )
        case .accelerationGY:
            guard let accelerationY else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(accelerationY),
                unit: "g",
                label: "Acc. Y"
            )
        case .accelerationGZ:
            guard let accelerationZ else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(accelerationZ),
                unit: "g",
                label: "Acc. Z"
            )
        case .signalDbm:
            guard let rssi else { return nil }
            return measurementItem(
                code: code,
                value: "\(rssi)",
                unit: "dBm",
                label: "Signal strength"
            )
        case .measurementSequenceNumber:
            guard let measurementSequenceNumber else { return nil }
            return measurementItem(
                code: code,
                value: "\(measurementSequenceNumber)",
                unit: "",
                label: "Meas. seq. no."
            )
        case .aqiIndex:
            guard let co2, let pm25 else { return nil }
            let value = calculateAQI(co2: co2, pm25: pm25)
            guard !value.isNaN else { return nil }
            return measurementItem(
                code: code,
                value: "\(Int(value.rounded(.toNearestOrAwayFromZero)))",
                unit: "",
                label: "Air quality"
            )
        case .co2ppm:
            guard let co2 else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(co2),
                unit: "ppm",
                label: "CO2"
            )
        case .vocIndex:
            guard let voc else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(voc),
                unit: "",
                label: "VOC"
            )
        case .noxIndex:
            guard let nox else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(nox),
                unit: "",
                label: "NOx"
            )
        case .pm10:
            guard let pm1 else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(pm1),
                unit: "µg/m³",
                label: "PM1"
            )
        case .pm25:
            guard let pm25 else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(pm25),
                unit: "µg/m³",
                label: "PM2.5"
            )
        case .pm40:
            guard let pm4 else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(pm4),
                unit: "µg/m³",
                label: "PM4"
            )
        case .pm100:
            guard let pm10 else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(pm10),
                unit: "µg/m³",
                label: "PM10"
            )
        case .luminosityLux:
            guard let luminosity else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(luminosity),
                unit: "lx",
                label: "Light"
            )
        case .soundInstantSpl:
            guard let soundInstant else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(soundInstant),
                unit: "dBA",
                label: "Sound inst."
            )
        case .soundAverage:
            guard let soundAverage else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(soundAverage),
                unit: "dBA",
                label: "Sound avg."
            )
        case .soundPeak:
            guard let soundPeak else { return nil }
            return measurementItem(
                code: code,
                value: preferences.formatFlexible(soundPeak),
                unit: "dBA",
                label: "Sound peak"
            )
        }
    }

    func measurementItem(
        code: DisplayCode,
        value: String,
        unit: String,
        label: String
    ) -> SensorMeasurementItem {
        SensorMeasurementItem(
            id: code.rawValue,
            value: value,
            unit: unit,
            label: label
        )
    }

    func absoluteHumidity(relativeHumidity: Double, temperatureCelsius: Double) -> Double {
        let saturationVaporPressure = 6.112 * exp((17.67 * temperatureCelsius) / (temperatureCelsius + 243.5))
        let vaporPressure = (relativeHumidity / 100.0) * saturationVaporPressure
        return (2.1674 * vaporPressure * 100.0) / (273.15 + temperatureCelsius)
    }

    func dewPoint(relativeHumidity: Double, temperatureCelsius: Double) -> Double {
        let a = 17.27
        let b = 237.7
        let alpha = ((a * temperatureCelsius) / (b + temperatureCelsius)) + log(relativeHumidity / 100.0)
        return (b * alpha) / (a - alpha)
    }

    func calculateAQI(co2: Double, pm25: Double) -> Double {
        let clampedPM25 = min(max(pm25, 0.0), 60.0)
        let clampedCO2 = min(max(co2, 420.0), 2300.0)

        let pm25Scale = 100.0 / 60.0
        let co2Scale = 100.0 / (2300.0 - 420.0)

        let dx = clampedPM25 * pm25Scale
        let dy = (clampedCO2 - 420.0) * co2Scale

        return min(max(100.0 - hypot(dx, dy), 0.0), 100.0)
    }
}

private extension WatchSensor {
    enum DisplayCode: String, CaseIterable, Hashable {
        case temperatureC = "TEMPERATURE_C"
        case temperatureF = "TEMPERATURE_F"
        case temperatureK = "TEMPERATURE_K"
        case humidityRelative = "HUMIDITY_0"
        case humidityAbsolute = "HUMIDITY_1"
        case humidityDewPoint = "HUMIDITY_2"
        case pressurePa = "PRESSURE_0"
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
        case soundInstantSpl = "SOUNDINSTANT_SPL"
        case measurementSequenceNumber = "MSN_COUNT"
        case co2ppm = "CO2_PPM"
        case vocIndex = "VOC_INDEX"
        case noxIndex = "NOX_INDEX"
        case pm10 = "PM10_MGM3"
        case pm25 = "PM25_MGM3"
        case pm40 = "PM40_MGM3"
        case pm100 = "PM100_MGM3"

        init?(rawCode: String) {
            self.init(rawValue: rawCode.uppercased())
        }
    }

    struct DisplayPreferences {
        let temperatureUnit: TemperatureUnit
        let humidityUnit: HumidityUnit
        let pressureUnit: PressureUnit
        let temperatureAccuracy: Accuracy
        let humidityAccuracy: Accuracy
        let pressureAccuracy: Accuracy

        init(defaults: UserDefaults?) {
            temperatureUnit = TemperatureUnit(defaults: defaults)
            humidityUnit = HumidityUnit(defaults: defaults)
            pressureUnit = PressureUnit(defaults: defaults)
            temperatureAccuracy = Accuracy(defaults?.integer(forKey: WatchSharedDefaults.temperatureAccuracyKey))
            humidityAccuracy = Accuracy(defaults?.integer(forKey: WatchSharedDefaults.humidityAccuracyKey))
            pressureAccuracy = Accuracy(defaults?.integer(forKey: WatchSharedDefaults.pressureAccuracyKey))
        }

        var temperatureCode: DisplayCode {
            switch temperatureUnit {
            case .celsius: return .temperatureC
            case .fahrenheit: return .temperatureF
            case .kelvin: return .temperatureK
            }
        }

        var humidityCode: DisplayCode {
            switch humidityUnit {
            case .relative: return .humidityRelative
            case .absolute: return .humidityAbsolute
            case .dewPoint: return .humidityDewPoint
            }
        }

        var pressureCode: DisplayCode {
            switch pressureUnit {
            case .pascals: return .pressurePa
            case .hectopascals: return .pressureHectopascal
            case .millimetersOfMercury: return .pressureMillimeterMercury
            case .inchesOfMercury: return .pressureInchMercury
            }
        }

        func formatFixed(_ value: Double, digits: Int) -> String {
            let formatter = NumberFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = digits
            formatter.maximumFractionDigits = digits
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }

        func formatFlexible(_ value: Double) -> String {
            let formatter = NumberFormatter()
            formatter.locale = .autoupdatingCurrent
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: value)) ?? String(value)
        }
    }

    enum TemperatureUnit {
        case kelvin
        case celsius
        case fahrenheit

        init(defaults: UserDefaults?) {
            switch defaults?.integer(forKey: WatchSharedDefaults.temperatureUnitKey) {
            case 1:
                self = .kelvin
            case 3:
                self = .fahrenheit
            case 2:
                self = .celsius
            default:
                self = .celsius
            }
        }

        var symbol: String {
            switch self {
            case .celsius:
                return "°C"
            case .fahrenheit:
                return "°F"
            case .kelvin:
                return "K"
            }
        }

        func convertFromCelsius(_ value: Double) -> Double {
            switch self {
            case .celsius:
                return value
            case .fahrenheit:
                return (value * 9 / 5) + 32
            case .kelvin:
                return value + 273.15
            }
        }
    }

    enum HumidityUnit {
        case relative
        case absolute
        case dewPoint

        init(defaults: UserDefaults?) {
            switch defaults?.integer(forKey: WatchSharedDefaults.humidityUnitKey) {
            case 1:
                self = .absolute
            case 2:
                self = .dewPoint
            default:
                self = .relative
            }
        }
    }

    enum PressureUnit {
        case pascals
        case hectopascals
        case millimetersOfMercury
        case inchesOfMercury

        init(defaults: UserDefaults?) {
            let rawValue = defaults?.integer(forKey: WatchSharedDefaults.pressureUnitKey)
            switch rawValue {
            case UnitPressure.newtonsPerMetersSquared.hashValue:
                self = .pascals
            case UnitPressure.inchesOfMercury.hashValue:
                self = .inchesOfMercury
            case UnitPressure.millimetersOfMercury.hashValue:
                self = .millimetersOfMercury
            default:
                self = .hectopascals
            }
        }
    }

    enum Accuracy {
        case zero
        case one
        case two

        init(_ rawValue: Int?) {
            switch rawValue {
            case 0:
                self = .zero
            case 1:
                self = .one
            default:
                self = .two
            }
        }

        var decimals: Int {
            switch self {
            case .zero:
                return 0
            case .one:
                return 1
            case .two:
                return 2
            }
        }

        func digits(for pressureUnit: PressureUnit) -> Int {
            switch pressureUnit {
            case .pascals:
                return 0
            default:
                return decimals
            }
        }
    }
}
