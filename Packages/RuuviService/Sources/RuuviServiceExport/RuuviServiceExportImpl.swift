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
    // swiftlint:disable:next function_body_length
    private func buildColumnDefinitions(
        firmware: RuuviFirmwareVersion,
        units: RuuviServiceMeasurementSettingsUnit,
        settings: RuuviLocalSettings
    ) -> [ColumnDefinition] {

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

        // MARK: Common columns
        // swiftlint:disable:next function_body_length
        func buildCommonColumns() -> [ColumnDefinition] {
            // Temperature, humidity, rssi, voltage, etc
            return [
                ColumnDefinition(
                    header: RuuviLocalization.ExportService.date,
                    cellExtractor: { record in
                        Self.dataDateFormatter.string(from: record.date)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.ExportService.temperature(units.temperatureUnit.symbol),
                    cellExtractor: { [weak self] record in
                        let val = self?.measurementService.double(for: record.temperature)
                        return toString(val)
                    }
                ),
                ColumnDefinition(
                    // if .dew, or else...
                    header: (units.humidityUnit == .dew)
                      ? RuuviLocalization.ExportService.humidity(units.temperatureUnit.symbol)
                      : RuuviLocalization.ExportService.humidity(units.temperatureUnit.symbol),
                    cellExtractor: { [weak self] record in
                        let val = self?.measurementService.double(
                            for: record.humidity,
                            temperature: record.temperature,
                            isDecimal: false
                        )
                        return toString(val)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.ExportService.pressure(units.pressureUnit.symbol),
                    cellExtractor: { [weak self] record in
                        let pressureVal = self?.measurementService.double(for: record.pressure)
                        if pressureVal == -0.01 { return toString(nil) }
                        return toString(pressureVal)
                    }
                ),
                ColumnDefinition(
                    header: "RSSI (\(RuuviLocalization.dBm))",
                    cellExtractor: { [weak self] record in
                        guard let sSelf = self else { return "" }
                        if let rssi = record.rssi {
                            return "\(rssi)"
                        }
                        return sSelf.emptyValueString
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.ExportService.voltage,
                    cellExtractor: { record in
                        let v = record.voltage?.converted(to: .volts).value
                        return toString(v)
                    }
                ),
            ]
        }

        // MARK: E0/F0 columns
        // swiftlint:disable:next function_body_length
        func buildE0F0Columns() -> [ColumnDefinition] {
            return [
                ColumnDefinition(
                    header: RuuviLocalization.aqi + " (%)",
                    cellExtractor: { [weak self] record in
                        guard let sSelf = self else { return "" }
                        let (aqi, _, _) = sSelf.measurementService.aqiString(
                            for: record.co2,
                            pm25: record.pm2_5,
                            voc: record.voc,
                            nox: record.nox
                        )
                        return "\(aqi)"
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.co2 + " (\(RuuviLocalization.unitCo2))",
                    cellExtractor: { record in
                        toString(record.co2)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.pm1 + " (\(RuuviLocalization.unitPm10))",
                    cellExtractor: { record in
                        toString(record.pm1)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.pm25 + " (\(RuuviLocalization.unitPm25))",
                    cellExtractor: { record in
                        toString(record.pm2_5)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.pm4 + " (\(RuuviLocalization.unitPm40))",
                    cellExtractor: { record in
                        toString(record.pm4)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.pm10 + " (\(RuuviLocalization.unitPm100))",
                    cellExtractor: { record in
                        toString(record.pm10)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.voc + " (\(RuuviLocalization.unitVoc))",
                    cellExtractor: { record in
                        toString(record.voc)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.nox + " (\(RuuviLocalization.unitNox))",
                    cellExtractor: { record in
                        toString(record.nox)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.soundAvg + " (\(RuuviLocalization.unitSound))",
                    cellExtractor: { record in
                        toString(record.dbaAvg)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.soundPeak + " (\(RuuviLocalization.unitSound))",
                    cellExtractor: { record in
                        toString(record.dbaPeak)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.luminosity + " (\(RuuviLocalization.unitLuminosity))",
                    cellExtractor: { record in
                        toString(record.luminance)
                    }
                ),
            ]
        }

        // MARK: v5 columns
        func buildV5Columns() -> [ColumnDefinition] {
            return [
                ColumnDefinition(
                    header: RuuviLocalization.ExportService.accelerationX + " (\(RuuviLocalization.g))",
                    cellExtractor: { record in
                        toString(record.acceleration?.x.value)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.ExportService.accelerationY + " (\(RuuviLocalization.g))",
                    cellExtractor: { record in
                        toString(record.acceleration?.y.value)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.ExportService.accelerationZ + " (\(RuuviLocalization.g))",
                    cellExtractor: { record in
                        toString(record.acceleration?.z.value)
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.ExportService.movementCounter +
                        " (\(RuuviLocalization.Cards.Movements.title))",
                    cellExtractor: { [weak self] record in
                        if let movementCounter = record.movementCounter {
                            return "\(movementCounter)"
                        }
                        guard let sSelf = self else { return "" }
                        return sSelf.emptyValueString
                    }
                ),
                ColumnDefinition(
                    header: RuuviLocalization.ExportService.txPower + " (\(RuuviLocalization.dBm))",
                    cellExtractor: { [weak self] record in
                        if let txPower = record.txPower {
                            return "\(txPower)"
                        }
                        guard let sSelf = self else { return "" }
                        return sSelf.emptyValueString
                    }
                ),
            ]
        }

        // Start assembling the columns
        var columns = buildCommonColumns()
        switch firmware {
        case .e0, .f0:
            columns += buildE0F0Columns()
        case .v5:
            columns += buildV5Columns()
        default:
            break
        }

        // Add measurement sequence number
        columns.append(ColumnDefinition(
            header: RuuviLocalization.ExportService.measurementSequenceNumber,
            cellExtractor: { [weak self] record in
                if let measurementSequenceNumber = record.measurementSequenceNumber {
                    return "\(measurementSequenceNumber)"
                }
                guard let sSelf = self else { return "" }
                return sSelf.emptyValueString
            }
        ))

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
                let firmware = RuuviFirmwareVersion.firmwareVersion(from: version)
                let columns = self.buildColumnDefinitions(
                    firmware: firmware,
                    units: self.measurementService.units,
                    settings: self.ruuviLocalSettings
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

                let firmwareType = RuuviFirmwareVersion.firmwareVersion(
                    from: version
                )

                let columns = self.buildColumnDefinitions(
                    firmware: firmwareType,
                    units: self.measurementService.units,
                    settings: self.ruuviLocalSettings
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
// swiftlint:enable file_length
