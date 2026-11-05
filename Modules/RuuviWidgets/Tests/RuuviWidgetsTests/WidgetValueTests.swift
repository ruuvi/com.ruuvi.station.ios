import Foundation
import RuuviCloud
import RuuviLocalization
import RuuviOntology
import XCTest
@testable import RuuviWidgets

@MainActor final class WidgetValueTests: XCTestCase {
    func testEveryMeasurementUsesCorrectRecordFieldAndUnitConversion() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let record = fixture.record(version: 6)
        let expected: [(RuuviCloudSensorVisibilityCode, Double)] = [
            (.temperatureC, 20), (.temperatureF, 68), (.temperatureK, 293.15),
            (.humidityRelative, 50), (.humidityAbsolute, 8.64), (.humidityDewPoint, 9.26),
            (.pressurePa, 100000), (.pressureHectopascal, 1000), (.pressureMillimeterMercury, 750.06),
            (.pressureInchMercury, 29.53),
            (.movementCount, 7), (.batteryVoltage, 3), (.accelerationGX, 1.25), (.accelerationGY, -0.5),
            (.accelerationGZ, 0),
            (.signalDbm, -60), (.luminosityLux, 100), (.soundAverage, 31), (.soundPeak, 32), (.soundInstant, 30),
            (.measurementSequenceNumber, 123), (.co2ppm, 420), (.vocIndex, 11), (.noxIndex, 12),
            (.pm10, 1.1), (.pm25, 2.2), (.pm40, 4.4), (.pm100, 10.5),
        ]
        XCTAssertEqual(Set(expected.map { $0.0 }).union([.aqiIndex]), Set(RuuviCloudSensorVisibilityCode.allCases))
        for (code, value) in expected {
            let config = fixture.config(code)
            let actual = fixture.model.getValue(from: record, settings: nil, config: config)
            XCTAssertEqual(try number(actual), value, accuracy: 0.1, code.rawValue)
            XCTAssertFalse(fixture.model.measurementShortName(from: config).isEmpty, code.rawValue)
        }
        XCTAssertEqual(fixture.model.getUnit(from: fixture.config(.temperatureF)), "°F")
        XCTAssertEqual(fixture.model.getUnit(from: fixture.config(.temperatureK)), "K")
        XCTAssertEqual(fixture.model.getUnit(from: fixture.config(.pressurePa)), "Pa")
        XCTAssertEqual(fixture.model.getUnit(from: fixture.config(.humidityRelative)), "%")
        XCTAssertEqual(fixture.model.getUnit(from: fixture.config(.vocIndex)), "")
        XCTAssertEqual(fixture.model.getUnit(from: fixture.config(.signalDbm)), "")
    }

    func testCalibrationAppliesOnceBeforeConversionAndMissingReadingsStayEmpty() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        var record = fixture.record()
        let settings = SensorSettingsStruct(
            luid: record.luid, macId: record.macId, temperatureOffset: 2,
            humidityOffset: 0.1, pressureOffset: 3)
        for (code, expected): (RuuviCloudSensorVisibilityCode, Double) in [
            (.temperatureF, 71.6), (.humidityRelative, 60), (.pressurePa, 100300),
        ] {
            XCTAssertEqual(
                try number(fixture.model.getValue(from: record, settings: settings, config: fixture.config(code))),
                expected, accuracy: 0.01)
        }
        record.temperature = nil
        record.humidity = nil
        record.pressure = nil
        record.acceleration = nil
        record.voltage = nil
        record.movementCounter = nil
        record.co2 = nil
        record.pm25 = nil
        record.rssi = nil
        for code: RuuviCloudSensorVisibilityCode in [
            .temperatureC, .humidityRelative, .pressurePa, .accelerationGX, .batteryVoltage, .movementCount, .aqiIndex,
            .co2ppm, .pm25, .signalDbm,
        ] {
            XCTAssertEqual(
                fixture.model.getValue(from: record, settings: settings, config: fixture.config(code)), "-",
                code.rawValue)
        }
        XCTAssertEqual(fixture.model.getValue(from: nil, settings: nil, config: .preview), "69.50")
    }

    func testLegacyNumericSelectionsAndInvalidSelectionFallbackRemainCompatible() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        for raw in 1...17 {
            let sensor = try XCTUnwrap(WidgetSensorEnum(rawValue: raw))
            let legacy = SingleSensorWidgetConfiguration(
                sensorId: "sensor", deviceType: .ruuviAir,
                sensorSelectionIdentifier: String(raw), sensor: .temperature)
            let direct = SingleSensorWidgetConfiguration(
                sensorId: "sensor", deviceType: .ruuviAir,
                sensorSelectionIdentifier: nil, sensor: sensor)
            XCTAssertEqual(fixture.model.getSensor(from: legacy), sensor)
            XCTAssertEqual(
                fixture.model.getValue(from: fixture.record(), settings: nil, config: legacy),
                fixture.model.getValue(from: fixture.record(), settings: nil, config: direct))
            XCTAssertEqual(fixture.model.getUnit(for: sensor), fixture.model.getUnit(from: direct))
            XCTAssertFalse(sensor.displayName().isEmpty)
            XCTAssertFalse(sensor.unit(from: fixture.model.getAppSettings()).isEmpty)
        }
        let invalid = SingleSensorWidgetConfiguration(
            sensorId: nil, deviceType: .unknown, sensorSelectionIdentifier: "missing", sensor: nil)
        XCTAssertEqual(
            fixture.model.getValue(from: fixture.record(), settings: nil, config: invalid),
            fixture.model.getValue(from: fixture.record(), settings: nil, config: .preview))
        XCTAssertEqual(fixture.model.getUnit(from: invalid), "°C")
        XCTAssertEqual(fixture.model.getUnit(for: nil), "°C")
        XCTAssertNil(fixture.model.getSensor(from: invalid))
    }

    func testMeasurementOptionsMatchDeviceCapabilitiesAndPresentReadings() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let tag = fixture.model.measurementOptions(for: .ruuviTag)
        let air = fixture.model.measurementOptions(for: .ruuviAir)
        XCTAssertTrue(tag.contains { $0.code == .batteryVoltage })
        XCTAssertFalse(tag.contains { $0.code == .co2ppm })
        XCTAssertTrue(air.contains { $0.code == .co2ppm })
        XCTAssertFalse(air.contains { $0.code == .movementCount })
        XCTAssertEqual(Set(tag.map(\.code)).count, tag.count)
        XCTAssertEqual(Set(air.map(\.code)).count, air.count)
        XCTAssertTrue((tag + air).allSatisfy { !$0.title.isEmpty })
        var sparse = fixture.record(version: 6)
        sparse.co2 = nil
        sparse.pm1 = nil
        sparse.dbaPeak = nil
        let sparseCodes = fixture.model.measurementOptions(for: .ruuviAir, using: sparse).map(\.code)
        XCTAssertFalse(sparseCodes.contains(.co2ppm))
        XCTAssertFalse(sparseCodes.contains(.aqiIndex))
        XCTAssertFalse(sparseCodes.contains(.pm10))
        XCTAssertFalse(sparseCodes.contains(.soundPeak))
        XCTAssertTrue(sparseCodes.contains(.pm25))
        XCTAssertEqual(fixture.model.deviceType(from: nil), .unknown)
        XCTAssertEqual(fixture.model.deviceType(from: fixture.record()), .ruuviTag)
        XCTAssertEqual(fixture.model.deviceType(from: fixture.record(version: 6)), .ruuviAir)
        XCTAssertEqual(fixture.model.deviceType(from: fixture.record(version: 225)), .ruuviAir)
    }

    func testVisibleIndicatorsRespectSelectionOrderDeduplicateAndHideMissingData() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let record = fixture.record(version: 6)
        let chosen: [RuuviCloudSensorVisibilityCode] = [.co2ppm, .temperatureF, .co2ppm, .pressurePa]
        let indicators = fixture.model.indicators(
            from: record, settings: nil, cloudSettings: nil,
            deviceType: .ruuviAir, selectedCodes: chosen)
        XCTAssertEqual(indicators.map(\.id), ["CO2_PPM", "TEMPERATURE_F", "PRESSURE_0"])
        XCTAssertEqual(indicators.map(\.hidesUnit), [false, false, false])
        let local = SensorSettingsStruct(
            luid: record.luid, macId: record.macId, temperatureOffset: nil,
            humidityOffset: nil, pressureOffset: nil, displayOrder: ["VOC_INDEX", "CO2_PPM", "VOC_INDEX"],
            defaultDisplayOrder: false)
        let visible = fixture.model.indicators(
            from: record, settings: local, cloudSettings: nil,
            deviceType: .ruuviAir, selectedCodes: [])
        XCTAssertEqual(visible.map(\.id), ["VOC_INDEX", "CO2_PPM"])
        XCTAssertTrue(visible[0].hidesUnit)
        var sparse = record
        sparse.co2 = nil
        XCTAssertTrue(
            fixture.model.indicators(
                from: sparse, settings: nil, cloudSettings: nil,
                deviceType: .ruuviAir, selectedCodes: [.co2ppm]
            ).isEmpty)
        XCTAssertTrue(
            fixture.model.indicators(
                from: nil, settings: nil, cloudSettings: nil,
                deviceType: .ruuviAir, selectedCodes: chosen
            ).isEmpty)
    }

    func testDeepLinksEncodeIdentifiersAndPreferRecordIdentity() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let record = fixture.record()
        let url = try XCTUnwrap(fixture.model.widgetDeepLinkURL(sensorId: "old", record: record))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "ruuviwidget")
        XCTAssertEqual(components.host, "open")
        XCTAssertEqual(components.queryItems?.first?.value, record.macId?.value)
        let special = "Room & sensor=?# 温度"
        let encoded = try XCTUnwrap(fixture.model.widgetDeepLinkURL(sensorId: special, record: nil))
        XCTAssertEqual(URLComponents(url: encoded, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, special)
        XCTAssertNil(fixture.model.widgetDeepLinkURL(sensorId: nil, record: nil))
        XCTAssertNil(fixture.model.widgetDeepLinkURL(sensorId: "", record: nil))
    }

    private func number(_ string: String) throws -> Double {
        let formatter = NumberFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.numberStyle = .decimal
        return try XCTUnwrap(formatter.number(from: string), string).doubleValue
    }

    func testLegacyDewPointUsesAppTemperatureUnitAndRelativeTimeUsesRecordDate() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        fixture.defaults.set(2, forKey: Constants.humidityUnitKey.rawValue)
        let config = SingleSensorWidgetConfiguration(
            sensorId: "sensor", deviceType: .ruuviTag,
            sensorSelectionIdentifier: nil, sensor: .humidity)
        for (raw, expected, unit): (Int, Double, String) in [(2, 9.26, "°C"), (3, 48.67, "°F"), (1, 282.41, "K")] {
            fixture.defaults.set(raw, forKey: Constants.temperatureUnitKey.rawValue)
            XCTAssertEqual(
                try number(fixture.model.getValue(from: fixture.record(), settings: nil, config: config)),
                expected, accuracy: 0.1)
            XCTAssertEqual(fixture.model.getUnit(from: config), unit)
        }
        let record = fixture.record(seconds: -120)
        let entry = WidgetEntry(
            date: fixture.date, isAuthorized: true, isPreview: false, tag: .preview,
            record: record, settings: nil, cloudSettings: nil, config: config)
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.unitsStyle = .abbreviated
        XCTAssertEqual(
            fixture.model.relativeMeasurementTime(from: entry),
            formatter.localizedString(for: record.date, relativeTo: fixture.date))
        XCTAssertEqual(fixture.model.airQualityDisplay(from: nil, config: fixture.config(.aqiIndex)).currentScore, 0)
        XCTAssertEqual(fixture.model.airQualityDisplay(from: record, config: config).currentScore, 0)
    }

    func testCloudVisibilityIgnoresUnknownCodesAndHonorsLocalOverrides() throws {
        let fixture = try WidgetFixture()
        defer { fixture.clean() }
        let record = fixture.record(version: 6)
        let cloud = RuuviCloudSensorSettings(
            displayOrderCodes: ["unrecognized", "CO2_PPM", "CO2_PPM", "TEMPERATURE_F"],
            defaultDisplayOrder: false)
        let cloudItems = fixture.model.indicators(
            from: record, settings: nil, cloudSettings: cloud,
            deviceType: .ruuviAir, selectedCodes: [])
        XCTAssertEqual(cloudItems.map(\.id), ["CO2_PPM", "TEMPERATURE_F"])
        let local = SensorSettingsStruct(
            luid: nil, macId: record.macId, temperatureOffset: nil,
            humidityOffset: nil, pressureOffset: nil,
            displayOrder: ["VOC_INDEX"], defaultDisplayOrder: false)
        XCTAssertEqual(
            fixture.model.indicators(
                from: record, settings: local, cloudSettings: cloud,
                deviceType: .ruuviAir, selectedCodes: []
            ).map(\.id), ["VOC_INDEX"])
        let unknown = RuuviCloudSensorSettings(displayOrderCodes: ["unknown"], defaultDisplayOrder: false)
        XCTAssertFalse(
            fixture.model.indicators(
                from: record, settings: nil, cloudSettings: unknown,
                deviceType: .ruuviAir, selectedCodes: []
            ).isEmpty)
    }
}
