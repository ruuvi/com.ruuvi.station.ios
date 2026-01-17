// swiftlint:disable file_length

import Foundation
import RuuviLocalization
import Future
import Humidity
import RuuviLocal
import RuuviOntology
import RuuviStorage
import xlsxwriter

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
    ) -> Future<
        URL,
        RuuviServiceError
    > {
        let promise = Promise<URL, RuuviServiceError>()
        let networkPruningOffset = -TimeInterval(ruuviLocalSettings.networkPruningIntervalHours * 60 * 60)
        let networkPuningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let ruuviTag = ruuviStorage.readOne(uuid)
        ruuviTag.on(success: { [weak self] ruuviTag in
            let recordsOperation = self?.ruuviStorage.readAll(uuid, after: networkPuningDate)
            recordsOperation?.on(success: { [weak self] records in
                let offsetedLogs = records.compactMap { $0.with(sensorSettings: settings) }
                self?.csvLog(for: ruuviTag, version: version, with: offsetedLogs)
                    .on(success: { url in
                    promise.succeed(value: url)
                }, failure: { error in
                    promise.fail(error: error)
                })
            }, failure: { error in
                promise.fail(error: .ruuviStorage(error))
            })
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })

        return promise.future
    }

    public func xlsxLog(
        for uuid: String,
        version: Int,
        settings: SensorSettings?
    ) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()

        let networkPruningOffset = -TimeInterval(ruuviLocalSettings.networkPruningIntervalHours * 60 * 60)
        let networkPuningDate = Date(timeIntervalSinceNow: networkPruningOffset)
        let ruuviTag = ruuviStorage.readOne(uuid)

        ruuviTag.on(success: { [weak self] ruuviTag in
            guard let self = self else { return }
            let recordsOperation = self.ruuviStorage.readAll(uuid, after: networkPuningDate)

            recordsOperation.on(success: { [weak self] records in
                guard let self = self else { return }
                let offsetedLogs = records.compactMap { $0.with(sensorSettings: settings) }
                self.exportToXlsx(for: ruuviTag, version: version, with: offsetedLogs)
                    .on(success: { url in
                    promise.succeed(value: url)
                }, failure: { error in
                    promise.fail(error: error)
                })
            }, failure: { error in
                promise.fail(error: .ruuviStorage(error))
            })
        }, failure: { error in
            promise.fail(error: .ruuviStorage(error))
        })

        return promise.future
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
        let hasVoltage = records.contains { $0.voltage != nil }
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
                  let temperature = record.temperature else {
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
                  let temperature = record.temperature else {
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
                  let temperature = record.temperature else {
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

        var columns: [ColumnDefinition] = [
            ColumnDefinition(
                header: RuuviLocalization.ExportService.date,
                cellExtractor: { record in
                    Self.dataDateFormatter.string(from: record.date)
                }
            ),
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
                        let v = record.voltage?.converted(to: .volts).value
                        return toString(v)
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
            columns.append(ColumnDefinition(
                header: RuuviLocalization.ExportService.dataSource,
                cellExtractor: { record in
                    record.source.rawValue
                }
            ))
        }

        return columns
    }

    // CSV export method
    private func csvLog(
        for ruuviTag: RuuviTagSensor,
        version: Int,
        with records: [RuuviTagSensorRecord]
    ) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        let date = Self.fileNameDateFormatter.string(from: Date())
        let fileName = ruuviTag.name + "_" + date + ".csv"
        let escapedFileName = fileName.replacingOccurrences(of: "/", with: "_")
        let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(escapedFileName)

        queue.async {
            autoreleasepool {
                let firmware = RuuviDataFormat.dataFormat(from: version)
                let columns = self.buildColumnDefinitions(
                    firmware: firmware,
                    settings: self.ruuviLocalSettings,
                    records: records
                )

                let headerLine = columns.map { $0.header }.joined(separator: ",")
                var csvText = headerLine + "\n"

                for record in records {
                    let rowValues = columns.map { $0.cellExtractor(record) }
                    csvText.append(rowValues.joined(separator: ","))
                    csvText.append("\n")
                }

                do {
                    try csvText.write(to: path, atomically: true, encoding: .utf8)
                    DispatchQueue.main.async {
                        promise.succeed(value: path)
                    }
                } catch {
                    DispatchQueue.main.async {
                        promise.fail(error: .writeToDisk(error))
                    }
                }
            }
        }

        return promise.future
    }

    // XLSX export method
    private func exportToXlsx(
        for ruuviTag: RuuviTagSensor,
        version: Int,
        with records: [RuuviTagSensorRecord]
    ) -> Future<URL, RuuviServiceError> {
        let promise = Promise<URL, RuuviServiceError>()
        let date = Self.fileNameDateFormatter.string(from: Date())
        let fileName = ruuviTag.name + "_" + date + ".xlsx"
        let escapedFileName = fileName.replacingOccurrences(of: "/", with: "_")
        let pathURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(escapedFileName)

        queue.async {
            autoreleasepool {

                let firmwareType = RuuviDataFormat.dataFormat(
                    from: version
                )

                let columns = self.buildColumnDefinitions(
                    firmware: firmwareType,
                    settings: self.ruuviLocalSettings,
                    records: records
                )

                let wb = Workbook(name: pathURL.path)
                defer { wb.close() }
                let ws = wb.addWorksheet()

                for (colIndex, colDef) in columns.enumerated() {
                    ws.write(.string(colDef.header), [0, colIndex])
                }

                for (rowIndex, record) in records.enumerated() {
                    for (colIndex, column) in columns.enumerated() {
                        let value = column.cellExtractor(record)
                        ws.write(.string(value), [rowIndex + 1, colIndex])
                    }
                }

                DispatchQueue.main.async {
                    promise.succeed(value: pathURL)
                }
            }
        }

        return promise.future
    }
}

extension UnitPressure {
    var ruuviSymbol: String {
        switch self {
        case .newtonsPerMetersSquared:
            return RuuviLocalization.pressurePaUnit
        default:
            return symbol
        }
    }
}

// swiftlint:enable file_length
