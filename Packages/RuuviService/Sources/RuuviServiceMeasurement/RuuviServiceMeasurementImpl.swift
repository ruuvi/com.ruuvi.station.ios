// swiftlint:disable file_length
import Foundation
import Humidity
import RuuviLocal
import RuuviOntology
// TODO: - @priyonto - Improve the number formatter instances.
public final class RuuviServiceMeasurementImpl: NSObject {
    var settings: RuuviLocalSettings {
        didSet {
            units = RuuviServiceMeasurementSettingsUnit(
                temperatureUnit: settings.temperatureUnit.unitTemperature,
                humidityUnit: settings.humidityUnit,
                pressureUnit: settings.pressureUnit
            )
        }
    }

    public var units: RuuviServiceMeasurementSettingsUnit {
        didSet {
            notifyListeners()
        }
    }

    private let emptyValueString: String
    private let percentString: String

    public init(
        settings: RuuviLocalSettings,
        emptyValueString: String,
        percentString: String
    ) {
        self.settings = settings
        self.emptyValueString = emptyValueString
        self.percentString = percentString
        units = RuuviServiceMeasurementSettingsUnit(
            temperatureUnit: settings.temperatureUnit.unitTemperature,
            humidityUnit: settings.humidityUnit,
            pressureUnit: settings.pressureUnit
        )
        super.init()
        startSettingsObserving()
    }

    private let notificationsNamesToObserve: [Notification.Name] = [
        .TemperatureUnitDidChange,
        .TemperatureAccuracyDidChange,
        .HumidityUnitDidChange,
        .HumidityAccuracyDidChange,
        .PressureUnitDidChange,
        .PressureUnitAccuracyChange,
    ]

    private var observers: [NSObjectProtocol] = []

    // Common formatter
    private var minimalNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }

    private var commonNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = NumberFormatter.RoundingMode.halfUp
        return formatter
    }

    private var commonFormatter: MeasurementFormatter {
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = Locale.autoupdatingCurrent
        measurementFormatter.unitOptions = .providedUnit
        measurementFormatter.numberFormatter = commonNumberFormatter
        return measurementFormatter
    }

    // Temperature formatter
    private var tempereatureNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = settings.temperatureAccuracy.value
        formatter.maximumFractionDigits = settings.temperatureAccuracy.value
        formatter.roundingMode = NumberFormatter.RoundingMode.halfUp
        return formatter
    }

    private var temperatureFormatter: MeasurementFormatter {
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = Locale.current
        measurementFormatter.unitOptions = .providedUnit
        measurementFormatter.numberFormatter = tempereatureNumberFormatter
        return measurementFormatter
    }

    // Humidity
    private var humidityNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = settings.humidityAccuracy.value
        formatter.maximumFractionDigits = settings.humidityAccuracy.value
        formatter.roundingMode = NumberFormatter.RoundingMode.halfUp
        return formatter
    }

    private var humidityFormatter: HumidityFormatter {
        let humidityFormatter = HumidityFormatter()
        humidityFormatter.numberFormatter = humidityNumberFormatter
        HumiditySettings.setLanguage(settings.language.humidityLanguage)
        return humidityFormatter
    }

    // Pressure
    private var pressureNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        let digits = units.pressureUnit.resolvedAccuracyValue(from: settings.pressureAccuracy)
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        if units.pressureUnit == .newtonsPerMetersSquared {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        }
        formatter.roundingMode = NumberFormatter.RoundingMode.halfUp
        return formatter
    }

    private var pressureFormatter: MeasurementFormatter {
        let measurementFormatter = MeasurementFormatter()
        measurementFormatter.locale = Locale.current
        measurementFormatter.unitOptions = .providedUnit
        measurementFormatter.numberFormatter = pressureNumberFormatter
        return measurementFormatter
    }

    private var listeners = NSHashTable<AnyObject>.weakObjects()

    public func add(_ listener: RuuviServiceMeasurementDelegate) {
        guard !listeners.contains(listener) else { return }
        listeners.add(listener)
    }
}

// MARK: - MeasurementsService

extension RuuviServiceMeasurementImpl: RuuviServiceMeasurement {
    public func double(for temperature: Temperature) -> Double {
        temperature
            .converted(to: units.temperatureUnit)
            .value
            .round(to: commonNumberFormatter.maximumFractionDigits)
    }

    public func string(for temperature: Temperature?, allowSettings: Bool) -> String {
        guard let temperature
        else {
            return emptyValueString
        }
        let value = temperature.converted(to: units.temperatureUnit).value
        let number = NSNumber(value: value)

        var numberFormatter = NumberFormatter()
        var measurementFormatter = MeasurementFormatter()
        if allowSettings {
            numberFormatter = tempereatureNumberFormatter
            measurementFormatter = temperatureFormatter
        } else {
            numberFormatter = commonNumberFormatter
            measurementFormatter = commonFormatter
        }
        if temperatureFormatter.unitStyle == .medium,
           settings.language == .english,
           let valueString = numberFormatter.string(from: number) {
            return String(
                format: "%@\(String.nbsp)%@",
                valueString,
                units.temperatureUnit.symbol
            )
        } else {
            return measurementFormatter.string(from: temperature.converted(to: units.temperatureUnit))
        }
    }

    public func stringWithoutSign(for temperature: Temperature?) -> String {
        guard let temperature
        else {
            return emptyValueString
        }
        let value = temperature.converted(to: units.temperatureUnit).value
        let number = NSNumber(value: value)
        tempereatureNumberFormatter.locale = Locale.current
        return tempereatureNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func stringWithoutSign(temperature: Double?) -> String {
        guard let temperature
        else {
            return emptyValueString
        }
        let number = NSNumber(value: temperature)
        return tempereatureNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func double(for pressure: Pressure) -> Double {
        let pressureValue = units.pressureUnit.convertedValue(from: pressure)
        if units.pressureUnit == .inchesOfMercury {
            return pressureValue
        } else if units.pressureUnit == .newtonsPerMetersSquared {
            return pressureValue.round(to: 0)
        } else {
            let digits = units.pressureUnit.supportsResolutionSelection ?
                commonNumberFormatter.maximumFractionDigits : 0
            return pressureValue.round(to: digits)
        }
    }

    public func string(
        for pressure: Pressure?,
        allowSettings: Bool
    ) -> String {
        guard let pressure
        else {
            return emptyValueString
        }
        let converted = units.pressureUnit.convert(pressure)
        if units.pressureUnit == .newtonsPerMetersSquared {
            let roundedValue = Double(Int(round(converted.value)))
            let value = String(Int(roundedValue))
            let symbol = units.pressureUnit.ruuviSymbol
            return "\(value)\(String.nbsp)\(symbol)"
        }
        if allowSettings {
            return pressureFormatter.string(from: converted)
        } else {
            return commonFormatter.string(from: converted)
        }
    }

    public func stringWithoutSign(for pressure: Pressure?) -> String {
        guard let pressure
        else {
            return emptyValueString
        }
        let pressureValue = units.pressureUnit.convertedValue(from: pressure)
        if units.pressureUnit == .newtonsPerMetersSquared {
            return String(Int(round(pressureValue)))
        }
        return pressureNumberFormatter.string(for: pressureValue) ?? emptyValueString
    }

    public func stringWithoutSign(pressure: Double?) -> String {
        guard let pressure
        else {
            return emptyValueString
        }
        if units.pressureUnit == .newtonsPerMetersSquared {
            return String(Int(round(pressure)))
        }
        let number = NSNumber(value: pressure)
        return pressureNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func double(for voltage: Voltage) -> Double {
        voltage
            .converted(to: .volts)
            .value
            .round(to: commonNumberFormatter.maximumFractionDigits)
    }

    public func string(for voltage: Voltage?) -> String {
        guard let voltage
        else {
            return emptyValueString
        }
        return commonFormatter.string(from: voltage.converted(to: .volts))
    }

    public func double(
        for humidity: Humidity,
        temperature: Temperature,
        isDecimal: Bool
    ) -> Double? {
        let humidityWithTemperature = Humidity(
            value: humidity.value,
            unit: .relative(temperature: temperature)
        )
        switch units.humidityUnit {
        case .percent:
            let value = humidityWithTemperature.value
            return isDecimal
                ? value
                .round(to: commonNumberFormatter.maximumFractionDigits)
                : (value * 100)
                .round(to: commonNumberFormatter.maximumFractionDigits)
        case .gm3:
            return humidityWithTemperature.converted(to: .absolute)
                .value
                .round(to: commonNumberFormatter.maximumFractionDigits)
        case .dew:
            let dp = try? humidityWithTemperature.dewPoint(temperature: temperature)
            return dp?.converted(to: settings.temperatureUnit.unitTemperature)
                .value
                .round(to: commonNumberFormatter.maximumFractionDigits)
        }
    }

    public func string(
        for humidity: Humidity?,
        temperature: Temperature?,
        allowSettings: Bool
    ) -> String {
        return string(
            for: humidity,
            temperature: temperature,
            allowSettings: allowSettings,
            unit: units.humidityUnit
        )
    }

    public func string(
        for humidity: Humidity?,
        temperature: Temperature?,
        allowSettings: Bool,
        unit: HumidityUnit
    ) -> String {
        guard let humidity,
              let temperature
        else {
            return emptyValueString
        }

        let humidityWithTemperature = Humidity(
            value: humidity.value,
            unit: .relative(temperature: temperature)
        )
        if allowSettings {
            humidityFormatter.numberFormatter = humidityNumberFormatter
        } else {
            humidityFormatter.numberFormatter = commonNumberFormatter
        }
        switch unit {
        case .percent:
            return humidityFormatter.string(from: humidityWithTemperature)
        case .gm3:
            return humidityFormatter.string(from: humidityWithTemperature.converted(to: .absolute))
        case .dew:
            guard let dp = try? humidityWithTemperature.dewPoint(temperature: temperature)
            else {
                return emptyValueString
            }
            let value = dp.converted(to: settings.temperatureUnit.unitTemperature).value
            guard let value = humidityNumberFormatter.string(from: NSNumber(value: value))
            else {
                return emptyValueString
            }
            return value + " " + settings.temperatureUnit.symbol
        }
    }

    public func stringWithoutSign(
        for humidity: Humidity?,
        temperature: Temperature?
    ) -> String {
        guard let humidity,
              let temperature
        else {
            return emptyValueString
        }

        let humidityWithTemperature = Humidity(
            value: humidity.value,
            unit: .relative(temperature: temperature)
        )

        switch units.humidityUnit {
        case .percent:
            let value = NSNumber(value: humidityWithTemperature.value * 100)
            return humidityNumberFormatter.string(from: value) ?? emptyValueString
        case .gm3:
            let value = humidityWithTemperature.converted(to: .absolute)
                .value
            return humidityNumberFormatter.string(from: NSNumber(value: value)) ?? emptyValueString
        case .dew:
            if let dp = try? humidityWithTemperature.dewPoint(temperature: temperature) {
                let value = dp.converted(to: settings.temperatureUnit.unitTemperature).value
                return humidityNumberFormatter.string(from: NSNumber(value: value)) ?? emptyValueString
            } else {
                return emptyValueString
            }
        }
    }

    public func stringWithoutSign(humidity: Double?) -> String {
        guard let humidity
        else {
            return emptyValueString
        }
        let number = NSNumber(value: humidity)
        return humidityNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func string(for measurement: Double?) -> String {
        guard let measurement
        else {
            return ""
        }
        let number = NSNumber(value: measurement)
        return commonNumberFormatter.string(from: number) ?? ""
    }

    public func string(
        from double: Double?
    ) -> String {
        guard let double
        else {
            return ""
        }
        let number = NSNumber(value: double)
        return minimalNumberFormatter.string(from: number) ?? ""
    }

    public func aqi(
        for co2: Double?,
        pm25: Double?,
    ) -> ( // swiftlint:disable:this large_tuple
        currentScore: Int,
        maxScore: Int,
        state: MeasurementQualityState
    ) {
        guard let co2 = co2, let pm25 = pm25 else {
            return (0, 100, .undefined(0))
        }

        let currentScore = calculateAQI(co2: co2, pm25: pm25)
            .rounded(.toNearestOrAwayFromZero)
        let maxScore = 100
        let state = airQualityState(for: currentScore)

        return (
            currentScore: Int(exactly: currentScore) ?? 0,
            maxScore: maxScore,
            state: state
        )
    }

    public func aqi(
        for co2: Double?,
        and pm25: Double?,
    ) -> Double {
        return calculateAQI(co2: co2, pm25: pm25).round(to: 1)
    }

    public func co2(for value: Double?) -> (
        value: Double,
        state: MeasurementQualityState
    ) {
        guard let value = value else {
            return (0, .excellent(0))
        }

        switch value {
        case 0..<420:
            return (value, .excellent(value))
        case 420..<600:
            return (value, .excellent(value))
        case 600..<800:
            return (value, .good(value))
        case 800..<1350:
            return (value, .fair(value))
        case 1350..<2100:
            return (value, .poor(value))
        case 2100...:
            return (value, .veryPoor(value))
        default:
            return (value, .excellent(value))
        }
    }

    public func pm25(for value: Double?) -> (
        value: Double,
        state: MeasurementQualityState
    ) {
        guard let value = value else {
            return (0, .excellent(0))
        }

        switch value {
        case 0..<5:
            return (value, .excellent(value))
        case 5..<12:
            return (value, .good(value))
        case 12..<30:
            return (value, .fair(value))
        case 30..<55:
            return (value, .poor(value))
        case 55...:
            return (value, .veryPoor(value))
        default:
            return (value, .excellent(value))
        }
    }

    public func aqiString(for aqi: Double?) -> String {
        guard let aqi else {
            return emptyValueString
        }
        let currentScore = aqi.rounded(.toNearestOrAwayFromZero)
        return commonNumberFormatter
            .string(from: NSNumber(value: currentScore)) ?? emptyValueString
    }

    public func co2String(for carbonDiOxide: Double?) -> String {
        guard let carbonDiOxide
        else {
            return emptyValueString
        }
        let number = NSNumber(value: Int(carbonDiOxide))
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func pm10String(for pm10: Double?) -> String {
        guard let pm10
        else {
            return emptyValueString
        }
        let number = NSNumber(value: pm10)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func pm25String(for pm25: Double?) -> String {
        guard let pm25
        else {
            return emptyValueString
        }
        let number = NSNumber(value: pm25)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func pm40String(for pm40: Double?) -> String {
        guard let pm40
        else {
            return emptyValueString
        }
        let number = NSNumber(value: pm40)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func pm100String(for pm100: Double?) -> String {
        guard let pm100
        else {
            return emptyValueString
        }
        let number = NSNumber(value: pm100)
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func vocString(for voc: Double?) -> String {
        guard let voc
        else {
            return emptyValueString
        }
        let number = NSNumber(value: Int(voc))
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func noxString(for nox: Double?) -> String {
        guard let nox
        else {
            return emptyValueString
        }
        let number = NSNumber(value: Int(nox))
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func soundString(for sound: Double?) -> String {
        guard let sound
        else {
            return emptyValueString
        }
        let number = NSNumber(value: Int(sound))
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func luminosityString(for luminosity: Double?) -> String {
        guard let luminosity
        else {
            return emptyValueString
        }
        let number = NSNumber(value: Int(luminosity))
        return commonNumberFormatter.string(from: number) ?? emptyValueString
    }

    public func double(for value: Double?) -> Double {
        return value?.round(to: commonNumberFormatter.maximumFractionDigits) ?? 0
    }
}

// MARK: - Private

extension RuuviServiceMeasurementImpl {
    private func notifyListeners() {
        listeners
            .allObjects
            .compactMap {
                $0 as? RuuviServiceMeasurementDelegate
            }.forEach {
                $0.measurementServiceDidUpdateUnit()
            }
    }

    private func updateCache() {
        updateUnits()
        notifyListeners()
    }

    public func updateUnits() {
        units = RuuviServiceMeasurementSettingsUnit(
            temperatureUnit: settings.temperatureUnit.unitTemperature,
            humidityUnit: settings.humidityUnit,
            pressureUnit: settings.pressureUnit
        )
    }

    private func startSettingsObserving() {
        notificationsNamesToObserve.forEach {
            let observer = NotificationCenter
                .default
                .addObserver(
                    forName: $0,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.updateCache()
                }
            self.observers.append(observer)
        }
    }
}

public extension RuuviServiceMeasurementImpl {
    func temperatureOffsetCorrection(for temperature: Double) -> Double {
        switch units.temperatureUnit {
        case .fahrenheit:
            temperature * 1.8
        default:
            temperature
        }
    }

    func temperatureOffsetCorrectionString(for temperature: Double) -> String {
        string(for: Temperature(
            temperatureOffsetCorrection(for: temperature),
            unit: units.temperatureUnit
        ), allowSettings: false)
    }

    func humidityOffsetCorrection(for humidity: Double) -> Double {
        humidity
    }

    func humidityOffsetCorrectionString(for humidity: Double) -> String {
        commonFormatter.string(
            from: Humidity(
                value: humidityOffsetCorrection(for: humidity) * 100,
                unit: UnitHumidity.relative(
                    temperature: Temperature(
                        value: 0.0,
                        unit: UnitTemperature.celsius
                    )
                )
            )
        )
    }

    func pressureOffsetCorrection(for pressure: Double) -> Double {
        double(for: Pressure(value: pressure, unit: .hectopascals))
    }

    func pressureOffsetCorrectionString(for pressure: Double) -> String {
        string(for: Pressure(
            pressureOffsetCorrection(for: pressure),
            unit: units.pressureUnit
        ), allowSettings: false)
    }

    private func calculateAQI(co2: Double?, pm25: Double?) -> Double {
        enum AQIConstants {
            static let maxValue = 100.0

            enum PM25 {
                static let range = 0.0...60.0
                static var scale: Double { AQIConstants.maxValue / (range.upperBound - range.lowerBound) }
            }

            enum CO2 {
                static let range = 420.0...2300.0
                static var scale: Double { AQIConstants.maxValue / (range.upperBound - range.lowerBound) }
            }
        }

        func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
            min(max(value, range.lowerBound), range.upperBound)
        }

        guard let pm25, let co2, !pm25.isNaN, !co2.isNaN else {
            return .nan
        }

        let clampedPM25 = clamped(pm25, to: AQIConstants.PM25.range)
        let clampedCO2 = clamped(co2, to: AQIConstants.CO2.range)

        let dx = (clampedPM25 - AQIConstants.PM25.range.lowerBound) * AQIConstants.PM25.scale
        let dy = (clampedCO2 - AQIConstants.CO2.range.lowerBound) * AQIConstants.CO2.scale

        let distance = hypot(dx, dy)

        return clamped((AQIConstants.maxValue - distance), to: 0...AQIConstants.maxValue)
    }

    /*
        Score Range  | State       | Color       | Description
        -------------|-------------|-------------|---------------------------
        89.5-100     | Excellent   | Turquoise   | Excellent air quality
        79.5<89.5    | Good        | Green       | Good air quality
        49.5<79.5    | Fair        | Yellow      | Fair air quality
        9.5<49.5     | Poor        | Orange      | Poor air quality
        0<9.5        | Very Poor   | Red         | Unhealthy air quality
     */
    private func airQualityState(for score: Double) -> MeasurementQualityState {
        switch score {
        case 89.5...:
            return .excellent(score)
        case 79.5..<89.5:
            return .good(score)
        case 49.5..<79.5:
            return .fair(score)
        case 9.5..<49.5:
            return .poor(score)
        default: // score < 9.5
            return .veryPoor(score)
        }
    }
}

extension String {
    static let nbsp = "\u{00a0}"
}

public extension Double {
    var stringValue: String {
        self == 0.0 ? formattedStringValue(places: 0) : String(self)
    }

    func formattedStringValue(places: Int) -> String {
        String(format: "%.\(places)f", self)
    }

    func round(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        let rounded = (self * divisor).rounded(.toNearestOrAwayFromZero) / divisor
        return rounded.isInfinite ? 0 : rounded
    }
}
