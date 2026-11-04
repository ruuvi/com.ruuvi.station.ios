#if SWIFT_PACKAGE
    import RuuviService
#endif
// swiftlint:disable file_length

import Foundation
import RuuviLocalization
import Humidity
import RuuviLocal
import RuuviOntology
import RuuviStorage
import libxlsxwriter

public final class RuuviServiceExportImpl: RuuviServiceExport {

    fileprivate struct ColumnDefinition {
        let header: String
        let cellExtractor: (RuuviTagSensorRecord) -> String
    }

    private let ruuviStorage: RuuviStorage
    private let measurementService: RuuviServiceMeasurement
    private let emptyValueString: String
    private let ruuviLocalSettings: RuuviLocalSettings

    public init(
        ruuviStorage: RuuviStorage,
        measurementService: RuuviServiceMeasurement,
        emptyValueString: String,
        ruuviLocalSettings: RuuviLocalSettings
    ) {
        self.ruuviStorage = ruuviStorage
        self.measurementService = measurementService
        self.emptyValueString = emptyValueString
        self.ruuviLocalSettings = ruuviLocalSettings
    }

    private var queue = DispatchQueue(label: "com.ruuvi.station.RuuviServiceExportImpl.queue", qos: .userInitiated)

    private var numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.decimalSeparator = "."
        numberFormatter.usesGroupingSeparator = false
        return numberFormatter
    }()

    private static let fileNameDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmssZ"
        return dateFormatter
    }()

    private static let dataDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter
    }()

    public func csvLog(
        for uuid: String,
        version: Int,
        settings: SensorSettings?
    ) async throws(RuuviServiceError) -> URL {
        guard !Task.isCancelled else { throw .writeToDisk(CancellationError()) }
        let historyStart = RuuviHistoryWindow.start(limitHours: ruuviLocalSettings.dataPruningOffsetHours)
        let sensor: AnyRuuviTagSensor
        let records: [RuuviTagSensorRecord]
        do {
            sensor = try await ruuviStorage.readOne(uuid)
            records = try await ruuviStorage.readAll(uuid, after: historyStart)
        } catch { throw .ruuviStorage(error) }
        let corrected = records.compactMap { $0.with(sensorSettings: settings) }
        return try await csvLog(for: sensor, version: version, with: corrected)
    }

    public func xlsxLog(
        for uuid: String,
        version: Int,
        settings: SensorSettings?
    ) async throws(RuuviServiceError) -> URL {
        guard !Task.isCancelled else { throw .writeToDisk(CancellationError()) }
        let historyStart = RuuviHistoryWindow.start(limitHours: ruuviLocalSettings.dataPruningOffsetHours)
        let sensor: AnyRuuviTagSensor
        let records: [RuuviTagSensorRecord]
        do {
            sensor = try await ruuviStorage.readOne(uuid)
            records = try await ruuviStorage.readAll(uuid, after: historyStart)
        } catch { throw .ruuviStorage(error) }
        let corrected = records.compactMap { $0.with(sensorSettings: settings) }
        return try await exportToXlsx(for: sensor, version: version, with: corrected)
    }
}

// MARK: - Private

extension RuuviServiceExportImpl {

    // Helper function that builds the column with the header and a closure
    // that extracts the cell value.
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func buildColumnDefinitions(
        firmware: RuuviDataFormat,
        settings: RuuviLocalSettings,
        records: [RuuviTagSensorRecord]
    ) -> [ColumnDefinition] {

        let emptyValueString = emptyValueString
        let measurementService = measurementService
        let includeAirMeasurements = firmware == .e1 || firmware == .v6
        let includeTagMeasurements = firmware == .v5
        let hasTemperature = records.contains { $0.temperature != nil }
        let hasHumidityAndTemperature = records.contains { $0.humidity != nil && $0.temperature != nil }
        let hasPressure = records.contains { record in
            guard let pressure = record.pressure else { return false }
            return pressure.converted(to: .hectopascals).value != -0.01
        }
        let hasRssi = records.contains { $0.rssi != nil }
        let hasVoltage = records.contains { record in
            guard let voltage = record.voltage else { return false }
            return voltage.converted(to: .volts).value != 0
        }
        let hasMovement = records.contains { $0.movementCounter != nil }
        let hasAcceleration = records.contains { $0.acceleration != nil }
        let hasMeasurementSequenceNumber = records.contains { $0.measurementSequenceNumber != nil }
        let hasCo2 = records.contains { $0.co2 != nil }
        let hasPm1 = records.contains { $0.pm1 != nil }
        let hasPm25 = records.contains { $0.pm25 != nil }
        let hasPm4 = records.contains { $0.pm4 != nil }
        let hasPm10 = records.contains { $0.pm10 != nil }
        let hasVoc = records.contains { $0.voc != nil }
        let hasNox = records.contains { $0.nox != nil }
        let hasAqi = records.contains { record in
            let aqi = measurementService.aqi(for: record.co2, and: record.pm25)
            return aqi.isFinite
        }
        let hasSoundInstant = records.contains(where: { $0.dbaInstant != nil })
        let hasSoundAvg = records.contains(where: { $0.dbaAvg != nil })
        let hasSoundPeak = records.contains(where: { $0.dbaPeak != nil })
        let hasLuminance = records.contains(where: { $0.luminance != nil })

        // Local numeric-to-string helper
        func toString(
            _ value: Double?,
            minDecimal: Int = 0,
            maxDecimal: Int = 3
        ) -> String {
            guard let v = value else { return emptyValueString }
            numberFormatter.minimumFractionDigits = minDecimal
            numberFormatter.maximumFractionDigits = maxDecimal
            return numberFormatter.string(from: NSNumber(value: v)) ?? emptyValueString
        }

        // swiftlint:disable:next cyclomatic_complexity function_body_length
        func shortName(for variant: MeasurementDisplayVariant) -> String {
            switch variant.type {
            case .temperature:
                return RuuviLocalization.temperature
            case .humidity:
                switch variant.humidityUnit ?? .percent {
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
        func shortNameWithUnit(for variant: MeasurementDisplayVariant) -> String {
            switch variant.type {
            case .temperature:
                let unit = variant.temperatureUnit ?? .celsius
                return RuuviLocalization.temperatureWithUnit(unit.symbol)
            case .humidity:
                let name = shortName(for: variant)
                let temperatureUnit = variant.temperatureUnit ?? .celsius
                let unit = variant.humidityUnit ?? .percent
                let unitSymbol: String
                switch unit {
                case .percent:
                    unitSymbol = RuuviLocalization.humidityRelativeUnit
                case .gm3:
                    unitSymbol = RuuviLocalization.gm³
                case .dew:
                    unitSymbol = temperatureUnit.symbol
                }
                if unit == .dew {
                    return name + " (\(temperatureUnit.symbol))"
                } else {
                    return name + " (\(unitSymbol))"
                }
            case .pressure:
                let unit = variant.pressureUnit ?? .hectopascals
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
                return RuuviLocalization.voc
            case .nox:
                return RuuviLocalization.nox
            case .soundInstant:
                return RuuviLocalization.soundInstantWithUnit(RuuviLocalization.unitSound)
            case .soundAverage:
                return RuuviLocalization.soundAverageWithUnit(RuuviLocalization.unitSound)
            case .soundPeak:
                return RuuviLocalization.soundPeakWithUnit(RuuviLocalization.unitSound)
            case .luminosity:
                return RuuviLocalization.luminosityWithUnit(RuuviLocalization.unitLuminosity)
            case .rssi:
                return RuuviLocalization.signalStrengthDbm
            default:
                return shortName(for: variant)
            }
        }

        func temperatureValue(
            for record: RuuviTagSensorRecord,
            unit: UnitTemperature
        ) -> String {
            guard let temperature = record.temperature else { return emptyValueString }
            let value = temperature.converted(to: unit).value.round(to: 2)
            return toString(value)
        }

        func humidityRelativeValue(
            for record: RuuviTagSensorRecord
        ) -> String {
            guard let humidity = record.humidity,
                let temperature = record.temperature
            else {
                return emptyValueString
            }
            let base = Humidity(value: humidity.value, unit: .relative(temperature: temperature))
            let percentValue = (base.value * 100).round(to: 2)
            return toString(percentValue)
        }

        func humidityAbsoluteValue(
            for record: RuuviTagSensorRecord
        ) -> String {
            guard let humidity = record.humidity,
                let temperature = record.temperature
            else {
                return emptyValueString
            }
            let base = Humidity(value: humidity.value, unit: .relative(temperature: temperature))
            let absoluteValue = base.converted(to: .absolute).value.round(to: 2)
            return toString(absoluteValue)
        }

        func dewPointValue(
            for record: RuuviTagSensorRecord,
            unit: UnitTemperature
        ) -> String {
            guard let humidity = record.humidity,
                let temperature = record.temperature
            else {
                return emptyValueString
            }
            let base = Humidity(value: humidity.value, unit: .relative(temperature: temperature))
            guard let dewPoint = try? base.dewPoint(temperature: temperature) else {
                return emptyValueString
            }
            let value = dewPoint.converted(to: unit).value.round(to: 2)
            return toString(value)
        }

        func pressureValue(
            for record: RuuviTagSensorRecord,
            unit: UnitPressure
        ) -> String {
            guard let pressure = record.pressure else { return emptyValueString }
            if pressure.converted(to: .hectopascals).value == -0.01 {
                return emptyValueString
            }
            let convertedValue = unit.convertedValue(from: pressure)
            if unit == .newtonsPerMetersSquared {
                return toString(convertedValue.round(to: 0), maxDecimal: 0)
            }
            if unit == .inchesOfMercury {
                return toString(convertedValue)
            }
            return toString(convertedValue.round(to: 2))
        }

        func movementValue(
            for record: RuuviTagSensorRecord
        ) -> String {
            guard let movementCounter = record.movementCounter else { return emptyValueString }
            return "\(movementCounter)"
        }

        func measurementSequenceNumberValue(
            for record: RuuviTagSensorRecord
        ) -> String {
            guard let measurementSequenceNumber = record.measurementSequenceNumber else {
                return emptyValueString
            }
            return "\(measurementSequenceNumber)"
        }

        func rssiValue(
            for record: RuuviTagSensorRecord
        ) -> String {
            guard let rssi = record.rssi else { return emptyValueString }
            return "\(rssi)"
        }

        func voltageValue(
            for record: RuuviTagSensorRecord
        ) -> String {
            guard let voltage = record.voltage else { return emptyValueString }
            let value = voltage.converted(to: .volts).value
            if value == 0 {
                return emptyValueString
            }
            return toString(value)
        }

        var columns: [ColumnDefinition] = [
            ColumnDefinition(
                header: RuuviLocalization.ExportService.date,
                cellExtractor: { record in
                    Self.dataDateFormatter.string(from: record.date)
                }
            )
        ]

        if includeAirMeasurements {
            if hasAqi {
                columns.append(
                    ColumnDefinition(
                        header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .aqi)),
                        cellExtractor: { record in
                            let aqi = measurementService.aqi(
                                for: record.co2,
                                and: record.pm25
                            )
                            if aqi.isFinite {
                                return "\(aqi)"
                            }
                            return emptyValueString
                        }
                    )
                )
            }
            if hasCo2 {
                columns.append(
                    ColumnDefinition(
                        header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .co2)),
                        cellExtractor: { record in
                            toString(record.co2)
                        }
                    )
                )
            }
            if hasPm1 {
                columns.append(
                    ColumnDefinition(
                        header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .pm10)),
                        cellExtractor: { record in
                            toString(record.pm1)
                        }
                    )
                )
            }
            if hasPm25 {
                columns.append(
                    ColumnDefinition(
                        header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .pm25)),
                        cellExtractor: { record in
                            toString(record.pm25)
                        }
                    )
                )
            }
            if hasPm4 {
                columns.append(
                    ColumnDefinition(
                        header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .pm40)),
                        cellExtractor: { record in
                            toString(record.pm4)
                        }
                    )
                )
            }
            if hasPm10 {
                columns.append(
                    ColumnDefinition(
                        header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .pm100)),
                        cellExtractor: { record in
                            toString(record.pm10)
                        }
                    )
                )
            }
            if hasVoc {
                columns.append(
                    ColumnDefinition(
                        header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .voc)),
                        cellExtractor: { record in
                            toString(record.voc)
                        }
                    )
                )
            }
            if hasNox {
                columns.append(
                    ColumnDefinition(
                        header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .nox)),
                        cellExtractor: { record in
                            toString(record.nox)
                        }
                    )
                )
            }
        }

        if hasTemperature {
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(
                        for: MeasurementDisplayVariant(
                            type: .temperature,
                            temperatureUnit: .celsius
                        )
                    ),
                    cellExtractor: { record in
                        temperatureValue(for: record, unit: .celsius)
                    }
                )
            )
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(
                        for: MeasurementDisplayVariant(
                            type: .temperature,
                            temperatureUnit: .fahrenheit
                        )
                    ),
                    cellExtractor: { record in
                        temperatureValue(for: record, unit: .fahrenheit)
                    }
                )
            )
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(
                        for: MeasurementDisplayVariant(
                            type: .temperature,
                            temperatureUnit: .kelvin
                        )
                    ),
                    cellExtractor: { record in
                        temperatureValue(for: record, unit: .kelvin)
                    }
                )
            )
        }

        if hasHumidityAndTemperature {
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(
                        for: MeasurementDisplayVariant(type: .humidity, humidityUnit: .percent)
                    ),
                    cellExtractor: { record in
                        humidityRelativeValue(for: record)
                    }
                )
            )
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(
                        for: MeasurementDisplayVariant(type: .humidity, humidityUnit: .gm3)
                    ),
                    cellExtractor: { record in
                        humidityAbsoluteValue(for: record)
                    }
                )
            )
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(
                        for: MeasurementDisplayVariant(
                            type: .humidity,
                            temperatureUnit: .celsius,
                            humidityUnit: .dew
                        )
                    ),
                    cellExtractor: { record in
                        dewPointValue(for: record, unit: .celsius)
                    }
                )
            )
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(
                        for: MeasurementDisplayVariant(
                            type: .humidity,
                            temperatureUnit: .fahrenheit,
                            humidityUnit: .dew
                        )
                    ),
                    cellExtractor: { record in
                        dewPointValue(for: record, unit: .fahrenheit)
                    }
                )
            )
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(
                        for: MeasurementDisplayVariant(
                            type: .humidity,
                            temperatureUnit: .kelvin,
                            humidityUnit: .dew
                        )
                    ),
                    cellExtractor: { record in
                        dewPointValue(for: record, unit: .kelvin)
                    }
                )
            )
        }

        if hasPressure {
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(
                        for: MeasurementDisplayVariant(
                            type: .pressure,
                            pressureUnit: .hectopascals
                        )
                    ),
                    cellExtractor: { record in
                        pressureValue(for: record, unit: .hectopascals)
                    }
                )
            )
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(
                        for: MeasurementDisplayVariant(
                            type: .pressure,
                            pressureUnit: .newtonsPerMetersSquared
                        )
                    ),
                    cellExtractor: { record in
                        pressureValue(for: record, unit: .newtonsPerMetersSquared)
                    }
                )
            )
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(
                        for: MeasurementDisplayVariant(
                            type: .pressure,
                            pressureUnit: .millimetersOfMercury
                        )
                    ),
                    cellExtractor: { record in
                        pressureValue(for: record, unit: .millimetersOfMercury)
                    }
                )
            )
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(
                        for: MeasurementDisplayVariant(
                            type: .pressure,
                            pressureUnit: .inchesOfMercury
                        )
                    ),
                    cellExtractor: { record in
                        pressureValue(for: record, unit: .inchesOfMercury)
                    }
                )
            )
        }

        if includeTagMeasurements && hasMovement {
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .movementCounter)),
                    cellExtractor: { record in
                        movementValue(for: record)
                    }
                )
            )
        }

        if includeAirMeasurements && hasSoundInstant {
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .soundInstant)),
                    cellExtractor: { record in
                        toString(record.dbaInstant)
                    }
                )
            )
        }

        if includeAirMeasurements && hasSoundAvg {
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .soundAverage)),
                    cellExtractor: { record in
                        toString(record.dbaAvg)
                    }
                )
            )
        }

        if includeAirMeasurements && hasSoundPeak {
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .soundPeak)),
                    cellExtractor: { record in
                        toString(record.dbaPeak)
                    }
                )
            )
        }

        if includeAirMeasurements && hasLuminance {
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .luminosity)),
                    cellExtractor: { record in
                        toString(record.luminance)
                    }
                )
            )
        }

        if includeTagMeasurements && hasVoltage {
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .voltage)),
                    cellExtractor: { record in
                        voltageValue(for: record)
                    }
                )
            )
        }
        if includeTagMeasurements && hasAcceleration {
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .accelerationX)),
                    cellExtractor: { record in
                        toString(record.acceleration?.x.value)
                    }
                )
            )
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .accelerationY)),
                    cellExtractor: { record in
                        toString(record.acceleration?.y.value)
                    }
                )
            )
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .accelerationZ)),
                    cellExtractor: { record in
                        toString(record.acceleration?.z.value)
                    }
                )
            )
        }

        if hasRssi {
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .rssi)),
                    cellExtractor: { record in
                        rssiValue(for: record)
                    }
                )
            )
        }

        if hasMeasurementSequenceNumber {
            columns.append(
                ColumnDefinition(
                    header: shortNameWithUnit(for: MeasurementDisplayVariant(type: .measurementSequenceNumber)),
                    cellExtractor: { record in
                        measurementSequenceNumberValue(for: record)
                    }
                )
            )
        }

        // Possibly data source
        if settings.includeDataSourceInHistoryExport {
            columns.append(
                ColumnDefinition(
                    header: RuuviLocalization.ExportService.dataSource,
                    cellExtractor: { record in
                        record.source.rawValue
                    }
                ))
        }

        return columns
    }

    static func csvCell(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func exportPath(for sensor: RuuviTagSensor, extension suffix: String) -> URL {
        let date = Self.fileNameDateFormatter.string(from: Date())
        let name = (sensor.name + "_" + date + "_" + UUID().uuidString + "." + suffix)
            .replacingOccurrences(of: "/", with: "_")
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
    }

    private func export(
        _ work: @escaping (ExportCancellation) throws -> URL
    ) async throws(RuuviServiceError) -> URL {
        let cancellation = ExportCancellation()
        let result: Result<URL, RuuviServiceError> = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled { cancellation.cancel() }
                queue.async {
                    let result: Result<URL, RuuviServiceError> = autoreleasepool {
                        do {
                            try cancellation.check()
                            let url = try work(cancellation)
                            do { try cancellation.check() } catch {
                                try? FileManager.default.removeItem(at: url); throw error
                            }
                            return .success(url)
                        } catch {
                            return .failure(.writeToDisk(error))
                        }
                    }
                    continuation.resume(returning: result)
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
        return try result.get()
    }

    private func csvLog(
        for ruuviTag: RuuviTagSensor,
        version: Int,
        with records: [RuuviTagSensorRecord]
    ) async throws(RuuviServiceError) -> URL {
        try await export { cancellation in
            let path = self.exportPath(for: ruuviTag, extension: "csv")
            let columns = self.buildColumnDefinitions(
                firmware: RuuviDataFormat.dataFormat(from: version),
                settings: self.ruuviLocalSettings, records: records)
            var csvText = columns.map { Self.csvCell($0.header) }.joined(separator: ",") + "\n"
            for record in records {
                try cancellation.check()
                csvText.append(columns.map { Self.csvCell($0.cellExtractor(record)) }.joined(separator: ",") + "\n")
            }
            try cancellation.check()
            try csvText.write(to: path, atomically: true, encoding: .utf8)
            return path
        }
    }

    private func exportToXlsx(
        for ruuviTag: RuuviTagSensor,
        version: Int,
        with records: [RuuviTagSensorRecord]
    ) async throws(RuuviServiceError) -> URL {
        try await export { cancellation in
            let path = self.exportPath(for: ruuviTag, extension: "xlsx")
            do {
                try self.writeWorkbook(to: path, version: version, records: records, cancellation: cancellation)
                return path
            } catch {
                try? FileManager.default.removeItem(at: path)
                throw error
            }
        }
    }

    private func writeWorkbook(
        to path: URL, version: Int, records: [RuuviTagSensorRecord],
        cancellation: ExportCancellation
    ) throws {
        let columns = buildColumnDefinitions(
            firmware: RuuviDataFormat.dataFormat(from: version),
            settings: ruuviLocalSettings, records: records)
        guard let workbook = workbook_new(path.path) else { throw CocoaError(.fileWriteUnknown) }
        var closed = false
        defer { if !closed { workbook_close(workbook) } }
        guard let worksheet = workbook_add_worksheet(workbook, nil) else { throw CocoaError(.fileWriteUnknown) }
        func check(_ error: lxw_error) throws {
            guard error != LXW_NO_ERROR else { return }
            throw NSError(
                domain: "RuuviExport", code: Int(error.rawValue),
                userInfo: [NSLocalizedDescriptionKey: String(cString: lxw_strerror(error))])
        }
        for (index, column) in columns.enumerated() {
            try check(worksheet_write_string(worksheet, 0, UInt16(index), column.header, nil))
        }
        for (row, record) in records.enumerated() {
            try cancellation.check()
            for (column, definition) in columns.enumerated() {
                try check(
                    worksheet_write_string(
                        worksheet, UInt32(row + 1), UInt16(column),
                        definition.cellExtractor(record), nil))
            }
        }
        // Closing finalizes the ZIP archive. Only expose the URL after all bytes are on disk.
        let error = workbook_close(workbook)
        closed = true
        try check(error)
    }
}

private final class ExportCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.withLock { cancelled = true } }
    func check() throws { if lock.withLock({ cancelled }) { throw CancellationError() } }
}

// swiftlint:enable file_length
