import Foundation
import Humidity
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviStorage
import Testing
@testable import RuuviService
#if SWIFT_PACKAGE
    import RuuviLocalUserDefaults
    @testable import RuuviServiceExport
    import RuuviServiceMeasurement
#endif

extension ExportTests {
    @Test(arguments: [5, 0xC5, 6, 225], [false, true])
    func exportedFilesPreserveEverySupportedReadingAndUnit(version: Int, useSIAcceleration: Bool) async throws {
        let fixture = try PropertiesFixture()
        try await fixture.pool.create(fixture.sensor)
        var populated = record(sensor: fixture.sensor, date: Date().addingTimeInterval(-120))
        populated.version = version
        populated.humidity = .init(value: 0.5, unit: .relative(temperature: populated.temperature!))
        populated.pressure = .init(value: 1013.25, unit: .hectopascals)
        populated.voltage = .init(value: 3.1, unit: .volts)
        let accelerationUnit: UnitAcceleration = useSIAcceleration ? .metersPerSecondSquared : .gravity
        populated.acceleration = .init(
            x: .init(value: -1, unit: .gravity).converted(to: accelerationUnit),
            y: .init(value: 0, unit: .gravity).converted(to: accelerationUnit),
            z: .init(value: 1, unit: .gravity).converted(to: accelerationUnit))
        if version == 0xC5 { populated.acceleration = nil }
        populated.movementCounter = 12
        populated.measurementSequenceNumber = 345
        populated.co2 = 420
        populated.pm1 = 1
        populated.pm25 = 0
        populated.pm4 = 4
        populated.pm10 = 10
        populated.voc = 123
        populated.nox = 45
        populated.dbaInstant = 32.1
        populated.dbaAvg = 31.2
        populated.dbaPeak = 52.3
        populated.luminance = 123.4
        var empty = record(sensor: fixture.sensor, date: populated.date.addingTimeInterval(60))
        empty.version = version
        empty.temperature = nil
        empty.rssi = nil
        empty.pressure = .init(value: -0.01, unit: .hectopascals)
        empty.voltage = .init(value: 0, unit: .volts)
        try await fixture.pool.create([populated, empty])
        let settings = RuuviLocalFactoryUserDefaults().createLocalSettings()
        let originalSource = settings.includeDataSourceInHistoryExport
        defer { settings.includeDataSourceInHistoryExport = originalSource }
        settings.includeDataSourceInHistoryExport = true
        let service = exporter(storage: fixture.storage, settings: settings)
        let csvURL = try await service.csvLog(for: fixture.sensor.id, version: version, settings: nil)
        let xlsxURL = try await service.xlsxLog(for: fixture.sensor.id, version: version, settings: nil)
        defer {
            try? FileManager.default.removeItem(at: csvURL)
            try? FileManager.default.removeItem(at: xlsxURL)
        }
        let csv = parseCSV(try String(contentsOf: csvURL, encoding: .utf8))
        let xlsx = try ExportWorkbookReader.rows(at: xlsxURL)
        #expect(xlsx == csv, "CSV and Excel must contain the same headers and cells")
        #expect(csv.count == 3)
        let headers = try #require(csv.first)
        let values = try #require(csv.dropFirst().first)
        let missing = try #require(csv.last)
        #expect(Set(headers).count == headers.count)
        #expect(values.count == headers.count)
        #expect(missing.count == headers.count)
        let row = Dictionary(uniqueKeysWithValues: zip(headers, values))
        let absent = Dictionary(uniqueKeysWithValues: zip(headers, missing))
        #expect(row[RuuviLocalization.ExportService.dataSource] == "log")
        #expect(absent[RuuviLocalization.ExportService.dataSource] == "log")
        let expectedColumns = expectedExportValues(for: version)
        for (header, expected) in expectedColumns {
            let actual = try #require(row[header].flatMap(Double.init), "Missing numeric column: \(header)")
            #expect(abs(actual - expected) < 0.06, "\(header): \(actual), expected \(expected)")
            #expect(absent[header] == "—", "Missing reading must stay empty: \(header)")
        }
        #expect(
            Set(headers)
                == Set(expectedColumns.keys).union([
                    RuuviLocalization.ExportService.date, RuuviLocalization.ExportService.dataSource,
                ]))
    }

    @Test(arguments: [false, true])
    func emptyHistoryProducesAReadableHeaderOnlyFile(xlsx: Bool) async throws {
        let fixture = try PropertiesFixture()
        var sensor = fixture.sensor
        sensor.name = "Room/Office"
        try await fixture.pool.create(sensor)
        let settings = RuuviLocalFactoryUserDefaults().createLocalSettings()
        let original = settings.includeDataSourceInHistoryExport
        defer { settings.includeDataSourceInHistoryExport = original }
        settings.includeDataSourceInHistoryExport = false
        let service = exporter(storage: fixture.storage, settings: settings)
        let url =
            try await
            (xlsx
            ? service.xlsxLog(for: sensor.id, version: 6, settings: nil)
            : service.csvLog(for: sensor.id, version: 6, settings: nil))
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(url.lastPathComponent.hasPrefix("Room_Office_"))
        let rows = try xlsx ? ExportWorkbookReader.rows(at: url) : parseCSV(String(contentsOf: url, encoding: .utf8))
        #expect(rows == [[RuuviLocalization.ExportService.date]])
    }

    private func expectedExportValues(for version: Int) -> [String: Double] {
        let universal: [String: Double] = [
            RuuviLocalization.temperatureWithUnit(UnitTemperature.celsius.symbol): 20,
            RuuviLocalization.temperatureWithUnit(UnitTemperature.fahrenheit.symbol): 68,
            RuuviLocalization.temperatureWithUnit(UnitTemperature.kelvin.symbol): 293.15,
            RuuviLocalization.relHumidity + " (" + RuuviLocalization.humidityRelativeUnit + ")": 50,
            RuuviLocalization.absHumidity + " (" + RuuviLocalization.gm³ + ")": 8.64,
            RuuviLocalization.dewpoint + " (°C)": 9.27,
            RuuviLocalization.dewpoint + " (°F)": 48.69,
            RuuviLocalization.dewpoint + " (K)": 282.42,
            RuuviLocalization.pressureWithUnit(UnitPressure.hectopascals.ruuviSymbol): 1013.25,
            RuuviLocalization.pressureWithUnit(UnitPressure.newtonsPerMetersSquared.ruuviSymbol): 101325,
            RuuviLocalization.pressureWithUnit(UnitPressure.millimetersOfMercury.ruuviSymbol): 760,
            RuuviLocalization.pressureWithUnit(UnitPressure.inchesOfMercury.ruuviSymbol): 29.921,
            RuuviLocalization.signalStrengthDbm: -55,
            RuuviLocalization.measSeqNumber: 345,
        ]
        var tag: [String: Double] = [
            RuuviLocalization.movements: 12,
            RuuviLocalization.battery + " (" + RuuviLocalization.v + ")": 3.1,
            RuuviLocalization.accX + " (" + RuuviLocalization.g + ")": -1,
            RuuviLocalization.accY + " (" + RuuviLocalization.g + ")": 0,
            RuuviLocalization.accZ + " (" + RuuviLocalization.g + ")": 1,
        ]
        if version == 0xC5 {
            for name in [RuuviLocalization.accX, RuuviLocalization.accY, RuuviLocalization.accZ] {
                tag[name + " (" + RuuviLocalization.g + ")"] = nil
            }
        }
        let air: [String: Double] = [
            RuuviLocalization.airQuality: 100,
            RuuviLocalization.co2WithUnit(RuuviLocalization.unitCo2): 420,
            RuuviLocalization.pm10WithUnit(RuuviLocalization.unitPm10): 1,
            RuuviLocalization.pm25WithUnit(RuuviLocalization.unitPm25): 0,
            RuuviLocalization.pm40WithUnit(RuuviLocalization.unitPm40): 4,
            RuuviLocalization.pm100WithUnit(RuuviLocalization.unitPm100): 10,
            RuuviLocalization.voc: 123,
            RuuviLocalization.nox: 45,
            RuuviLocalization.soundInstantWithUnit(RuuviLocalization.unitSound): 32.1,
            RuuviLocalization.soundAverageWithUnit(RuuviLocalization.unitSound): 31.2,
            RuuviLocalization.soundPeakWithUnit(RuuviLocalization.unitSound): 52.3,
            RuuviLocalization.luminosityWithUnit(RuuviLocalization.unitLuminosity): 123.4,
        ]
        let isAir = version == 6 || version == 225
        return universal.merging(isAir ? air : tag, uniquingKeysWith: { first, _ in first })
    }

    private func parseCSV(_ text: String) -> [[String]] {
        var rows = [[String]]()
        var row = [String]()
        var cell = ""
        var quoted = false
        var iterator = text.makeIterator()
        var pending: Character?
        while let character = pending ?? iterator.next() {
            pending = nil
            if character == "\"" {
                if quoted {
                    let next = iterator.next()
                    if next == "\"" { cell.append("\"") } else { quoted = false; pending = next }
                } else {
                    quoted = true
                }
            } else if character == ",", !quoted {
                row.append(cell); cell = ""
            } else if character == "\n", !quoted {
                row.append(cell); rows.append(row); row = []; cell = ""
            } else {
                cell.append(character)
            }
        }
        return rows
    }
}
