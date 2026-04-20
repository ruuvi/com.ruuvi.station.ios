@testable import RuuviOntology
@testable import BTKit
import CoreLocation
import Humidity
import UIKit
import XCTest

final class RuuviOntologyCoverageTests: XCTestCase {
    func testTemperatureHelpersThemeAndAlertSoundExposeExpectedValues() {
        XCTAssertEqual(0.0.fahrenheit, 32.0)
        XCTAssertEqual(0.0.kelvin, 273.15, accuracy: 0.0001)
        XCTAssertEqual(212.0.celsiusFromFahrenheit, 100.0, accuracy: 0.0001)
        XCTAssertEqual(273.15.celsiusFromKelvin, 0.0, accuracy: 0.0001)

        XCTAssertEqual(RuuviTheme.light.uiInterfaceStyle, .light)
        XCTAssertEqual(RuuviTheme.dark.uiInterfaceStyle, .dark)
        XCTAssertEqual(RuuviTheme.system.uiInterfaceStyle, .unspecified)

        XCTAssertEqual(RuuviAlertSound.systemDefault.fileName, "default")
        XCTAssertEqual(RuuviAlertSound.ruuviSpeak.fileName, "ruuvi_speak")
    }

    func testReorderableNfcAndPhysicalSensorHelpersExposeExpectedValues() {
        let reordered = [
            ReorderableString(id: "third"),
            ReorderableString(id: "first"),
            ReorderableString(id: "second"),
            ReorderableString(id: "unknown")
        ].reorder(by: ["first", "second", "third"])

        XCTAssertEqual(reordered.map(\.id), ["first", "second", "third", "unknown"])
        XCTAssertEqual(
            [
                ReorderableString(id: "unknown"),
                ReorderableString(id: "first")
            ].reorder(by: ["first"]).map(\.id),
            ["first", "unknown"]
        )

        let nfcSensor = NFCSensor(id: "nfc-id", macId: "AA:BB:CC:11:22:33", firmwareVersion: "3.31.0")
        XCTAssertEqual(nfcSensor.id, "nfc-id")
        XCTAssertEqual(nfcSensor.macId, "AA:BB:CC:11:22:33")
        XCTAssertEqual(nfcSensor.firmwareVersion, "3.31.0")

        let withMac = PhysicalSensorStruct(luid: "luid-1".luid, macId: "AA:BB:CC:11:22:33".mac)
        let withOnlyLuid = PhysicalSensorStruct(luid: "luid-2".luid, macId: nil)
        let withEmptyMac = PhysicalSensorStruct(luid: "luid-3".luid, macId: "".mac)

        XCTAssertEqual(withMac.id, "AA:BB:CC:11:22:33")
        XCTAssertEqual(withOnlyLuid.id, "luid-2")
        XCTAssertEqual(withEmptyMac.id, "luid-3")
        XCTAssertEqual(PhysicalSensorStruct(luid: nil, macId: nil).id, "")
    }

    func testTemperatureUnitDefaultsAndRangesCoverPreferencesAndLocaleFallbacks() {
        let suiteName = "RuuviOntologyCoverageTests.\(#function)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            return XCTFail("Expected isolated user defaults suite")
        }
        userDefaults.removePersistentDomain(forName: suiteName)

        userDefaults.set(" fahrenheit ", forKey: "AppleTemperatureUnit")
        XCTAssertEqual(
            TemperatureUnit.defaultFromSystemPreferences(
                userDefaults: userDefaults,
                locale: Locale(identifier: "fi_FI")
            ),
            .fahrenheit
        )

        userDefaults.set("k", forKey: "AppleTemperatureUnit")
        XCTAssertEqual(
            TemperatureUnit.defaultFromSystemPreferences(
                userDefaults: userDefaults,
                locale: Locale(identifier: "en_GB")
            ),
            .kelvin
        )

        userDefaults.set("celsius", forKey: "AppleTemperatureUnit")
        XCTAssertEqual(
            TemperatureUnit.defaultFromSystemPreferences(
                userDefaults: userDefaults,
                locale: Locale(identifier: "en_US")
            ),
            .celsius
        )

        userDefaults.set(" c ", forKey: "AppleTemperatureUnit")
        XCTAssertEqual(
            TemperatureUnit.defaultFromSystemPreferences(
                userDefaults: userDefaults,
                locale: Locale(identifier: "en_US")
            ),
            .celsius
        )

        userDefaults.set("rankine", forKey: "AppleTemperatureUnit")
        let usDefault = TemperatureUnit.defaultFromSystemPreferences(
            userDefaults: userDefaults,
            locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(
            UnitTemperature.defaultFromSystemPreferences(
                userDefaults: userDefaults,
                locale: Locale(identifier: "en_US")
            ),
            usDefault.unitTemperature
        )
        XCTAssertEqual(
            TemperatureUnit.defaultFromSystemPreferences(
                userDefaults: userDefaults,
                locale: Locale(identifier: "fi_FI")
            ),
            .celsius
        )
        XCTAssertEqual(usDefault, .fahrenheit)

        let range = TemperatureUnit.fahrenheit.alertRange
        XCTAssertEqual(range.lowerBound, -40.0, accuracy: 0.0001)
        XCTAssertEqual(range.upperBound, 185.0, accuracy: 0.0001)
        XCTAssertEqual(TemperatureUnit.kelvin.symbol, UnitTemperature.kelvin.symbol)
    }

    func testTemperatureUnitParsingHelpersCoverRemainingPreferenceAndMeasurementCases() {
        XCTAssertEqual(TemperatureUnit.fromSystemPreference(" Fahrenheit "), .fahrenheit)
        XCTAssertEqual(TemperatureUnit.fromSystemPreference("kelvin"), .kelvin)
        XCTAssertEqual(TemperatureUnit.fromSystemPreference("c"), .celsius)
        XCTAssertNil(TemperatureUnit.fromSystemPreference("rankine"))
        XCTAssertNil(TemperatureUnit.fromSystemPreference(nil))

        XCTAssertEqual(TemperatureUnit.fromMeasurementSystemIdentifier("u.s."), .fahrenheit)
        XCTAssertEqual(TemperatureUnit.fromMeasurementSystemIdentifier(" us "), .fahrenheit)
        XCTAssertEqual(TemperatureUnit.fromMeasurementSystemIdentifier("metric"), .celsius)
        XCTAssertNil(TemperatureUnit.fromMeasurementSystemIdentifier(nil))

        if #available(iOS 16.0, *) {
            XCTAssertEqual(TemperatureUnit.fromMeasurementSystem(.us), .fahrenheit)
            XCTAssertEqual(TemperatureUnit.fromMeasurementSystem(.metric), .celsius)
            XCTAssertEqual(TemperatureUnit.fromMeasurementSystem(.uk), .celsius)
        }
    }

    func testTemperatureUnitBridgesFoundationUnitsForEveryCase() {
        XCTAssertEqual(TemperatureUnit.celsius.unitTemperature, .celsius)
        XCTAssertEqual(TemperatureUnit.fahrenheit.unitTemperature, .fahrenheit)
        XCTAssertEqual(TemperatureUnit.kelvin.unitTemperature, .kelvin)
        XCTAssertEqual(TemperatureUnit.celsius.symbol, UnitTemperature.celsius.symbol)
        XCTAssertEqual(TemperatureUnit.fahrenheit.symbol, UnitTemperature.fahrenheit.symbol)
    }

    func testMeasurementHelpersDataFormatsAndDisplayProfilesCoverFallbackBranches() {
        let temperature = Temperature(value: 21.5, unit: .celsius)
        let settings = SensorSettingsStruct(
            luid: "settings-luid".luid,
            macId: nil,
            temperatureOffset: 1.5,
            humidityOffset: 2.5,
            pressureOffset: 3.5
        )
        let humidity = Humidity(value: 0.45, unit: .relative(temperature: temperature))
        let pressure = Pressure(value: 1008.5, unit: .hectopascals)

        XCTAssertNil(Temperature(nil))
        XCTAssertNil(Pressure(nil))
        XCTAssertNil(Humidity(relative: nil, temperature: temperature))
        XCTAssertNil(Humidity(relative: 0.45, temperature: nil))
        XCTAssertEqual(Temperature(21.5)?.plus(sensorSettings: nil)?.value, 21.5)
        XCTAssertEqual(temperature.plus(sensorSettings: settings)?.value, 23.0)
        XCTAssertEqual(temperature.minus(value: nil)?.value, 21.5)
        XCTAssertEqual(pressure.plus(sensorSettings: nil)?.value, 1008.5)
        XCTAssertEqual(pressure.plus(sensorSettings: settings)?.value, 1012.0)
        XCTAssertEqual(pressure.minus(value: nil)?.value, 1008.5)
        XCTAssertEqual(humidity.plus(sensorSettings: nil)?.value, 0.45)
        XCTAssertEqual(humidity.plus(sensorSettings: settings)?.value, 2.95)
        XCTAssertEqual(humidity.minus(value: nil)?.value, 0.45)
        XCTAssertEqual(Humidity.zeroAbsolute.value, 0)

        XCTAssertEqual(settings.id, "settings-luid-settings")
        XCTAssertEqual(
            SensorSettingsStruct(
                luid: nil,
                macId: nil,
                temperatureOffset: nil,
                humidityOffset: nil,
                pressureOffset: nil
            ).id,
            ""
        )
        XCTAssertEqual(RuuviDataFormat.dataFormat(from: 0xC5), .vC5)
        XCTAssertEqual(RuuviDataFormat.dataFormat(from: 5), .v5)
        XCTAssertEqual(RuuviDataFormat.dataFormat(from: 225), .e1)
        XCTAssertEqual(RuuviDataFormat.dataFormat(from: 6), .v6)
        XCTAssertEqual(RuuviDataFormat.dataFormat(from: 99), .v5)
        XCTAssertEqual(MeasurementDisplayDefaults.measurementOrder(for: .v6), MeasurementDisplayDefaults.airMeasurementOrder)
        XCTAssertEqual(MeasurementDisplayDefaults.measurementOrder(for: .vC5), MeasurementDisplayDefaults.tagMeasurementOrder)
        XCTAssertEqual(
            MeasurementDisplayDefaults.orderedMeasurements(for: [.rssi, .temperature, .txPower]),
            [.temperature, .rssi, .txPower]
        )

        let profile = MeasurementDisplayProfile(entries: [
            MeasurementDisplayEntry(.temperature, temperatureUnit: .celsius, contexts: [.indicator, .graph]),
            MeasurementDisplayEntry(.humidity, humidityUnit: .percent, visible: false),
            MeasurementDisplayEntry(.pressure, pressureUnit: .hectopascals, contexts: .alert),
            MeasurementDisplayEntry(.rssi, contexts: .none),
        ])

        XCTAssertEqual(profile.orderedVisibleTypes, [.temperature])
        XCTAssertEqual(profile.orderedVisibleVariants.map(\.type), [.temperature])
        XCTAssertEqual(profile.orderedVisibleTypes(for: .alert), [.pressure])
        XCTAssertEqual(profile.entries(for: .graph).map(\.type), [.temperature])
        XCTAssertEqual(profile.entriesSupporting(.indicator).map(\.type), [.temperature, .humidity])
        XCTAssertTrue(profile.entriesSupporting(.alert).contains { $0.type == .pressure })
    }

    func testRuuviTagWithNameMapsAdvertisementIntoSensorDefaults() {
        let tag = RuuviTag.v5(
            RuuviData5(
                uuid: "luid-1",
                rssi: -42,
                isConnectable: true,
                version: 5,
                humidity: 64.0,
                temperature: 21.5,
                pressure: 1001.0,
                accelerationX: 1,
                accelerationY: 2,
                accelerationZ: 3,
                voltage: 2.95,
                movementCounter: 4,
                measurementSequenceNumber: 10,
                txPower: 5,
                mac: "AA:BB:CC:11:22:33"
            )
        )

        let sensor = tag.with(name: "Basement")

        XCTAssertEqual(sensor.version, 5)
        XCTAssertEqual(sensor.luid?.value, "luid-1")
        XCTAssertEqual(sensor.macId?.value, "AA:BB:CC:11:22:33")
        XCTAssertEqual(sensor.name, "Basement")
        XCTAssertEqual(sensor.isCloudSensor, false)
        XCTAssertEqual(sensor.isOwner, true)
        XCTAssertLessThan(abs(tag.date.timeIntervalSinceNow), 1)

        let unidentifiedSensor = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: nil,
            luid: nil,
            macId: nil,
            serviceUUID: nil,
            isConnectable: false,
            name: "Unidentified",
            isClaimed: false,
            isOwner: false,
            owner: nil,
            ownersPlan: nil,
            isCloudSensor: nil,
            canShare: false,
            sharedTo: [],
            maxHistoryDays: nil
        )
        XCTAssertEqual(unidentifiedSensor.id, "")
    }

    func testAlertTypesPressureTokenAndBtKitRecordMappersCoverOntologyNativeBranches() {
        let expectedRawValues = [
            "temperature",
            "relativeHumidity",
            "absoluteHumidity",
            "dewPoint",
            "pressure",
            "signal",
            "batteryVoltage",
            "aqi",
            "carbonDioxide",
            "pMatter1",
            "pMatter25",
            "pMatter4",
            "pMatter10",
            "voc",
            "nox",
            "soundInstant",
            "soundPeak",
            "soundAverage",
            "luminosity",
            "connection",
            "cloudConnection",
            "movement",
        ]
        XCTAssertEqual(AlertType.allCases.map(\.rawValue), expectedRawValues)
        for rawValue in expectedRawValues {
            XCTAssertEqual(AlertType.alertType(from: rawValue)?.rawValue, rawValue)
        }
        XCTAssertNil(AlertType.alertType(from: "unknown-alert"))

        XCTAssertTrue(UnitPressure.hectopascals.supportsResolutionSelection)
        XCTAssertFalse(UnitPressure.newtonsPerMetersSquared.supportsResolutionSelection)
        XCTAssertEqual(UnitPressure.hectopascals.resolvedAccuracyValue(from: .two), 2)
        XCTAssertEqual(UnitPressure.newtonsPerMetersSquared.resolvedAccuracyValue(from: .two), 0)
        XCTAssertEqual(
            UnitPressure.newtonsPerMetersSquared.convert(value: 1, from: .hectopascals),
            100,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            UnitPressure.hectopascals.convert(value: 100, from: .newtonsPerMetersSquared),
            1,
            accuracy: 0.0001
        )
        let convertedPressure = UnitPressure.kilopascals.convert(
            Pressure(value: 1000, unit: .hectopascals)
        )
        XCTAssertEqual(convertedPressure.value, 100, accuracy: 0.0001)
        XCTAssertEqual(convertedPressure.unit, .kilopascals)

        let token = RuuviCloudPNTokenStruct(id: 7, lastAccessed: 12.5, name: "iPhone")
        let defaultToken = RuuviCloudPNTokenStruct(id: 8)
        XCTAssertEqual(token.id, 7)
        XCTAssertEqual(token.lastAccessed, 12.5)
        XCTAssertEqual(token.name, "iPhone")
        XCTAssertNil(defaultToken.lastAccessed)
        XCTAssertNil(defaultToken.name)

        let fullTag = RuuviTag.v5(
            RuuviData5(
                uuid: "tag-luid",
                rssi: -55,
                isConnectable: true,
                version: 5,
                humidity: 45,
                temperature: 21.5,
                pressure: 1001.5,
                accelerationX: 1,
                accelerationY: 2,
                accelerationZ: 3,
                voltage: 2.95,
                movementCounter: 6,
                measurementSequenceNumber: 7,
                txPower: 4,
                mac: "AA:BB:CC:11:22:33"
            )
        )
        XCTAssertEqual(fullTag.luid?.value, "tag-luid")
        XCTAssertEqual(fullTag.macId?.value, "AA:BB:CC:11:22:33")
        XCTAssertEqual(fullTag.source, .unknown)
        XCTAssertEqual(fullTag.temperature?.value, 21.5)
        XCTAssertEqual(fullTag.humidity?.value, 0.45)
        XCTAssertEqual(fullTag.pressure?.value, 1001.5)
        XCTAssertEqual(fullTag.acceleration?.x.value, 1)
        XCTAssertEqual(fullTag.acceleration?.y.value, 2)
        XCTAssertEqual(fullTag.acceleration?.z.value, 3)
        XCTAssertEqual(fullTag.voltage?.value, 2.95)
        XCTAssertEqual(fullTag.temperatureOffset, 0)
        XCTAssertEqual(fullTag.humidityOffset, 0)
        XCTAssertEqual(fullTag.pressureOffset, 0)

        let sparseTag = RuuviTag.v5(
            RuuviData5(
                uuid: "tag-luid",
                rssi: -55,
                isConnectable: true,
                version: 5,
                humidity: nil,
                temperature: nil,
                pressure: nil,
                accelerationX: nil,
                accelerationY: nil,
                accelerationZ: nil,
                voltage: nil,
                movementCounter: nil,
                measurementSequenceNumber: nil,
                txPower: nil,
                mac: "AA:BB:CC:11:22:33"
            )
        )
        XCTAssertNil(sparseTag.temperature)
        XCTAssertNil(sparseTag.humidity)
        XCTAssertNil(sparseTag.pressure)
        XCTAssertNil(sparseTag.acceleration)
        XCTAssertNil(sparseTag.voltage)

        let airTag = RuuviTag.vE1_V6(
            RuuviDataE1_V6(
                uuid: "air-luid",
                rssi: -50,
                isConnectable: false,
                version: 6,
                humidity: 42,
                temperature: 20,
                pressure: 1000,
                pm1: 1.1,
                pm25: 2.2,
                pm4: 4.4,
                pm10: 10.1,
                co2: 420,
                voc: 12,
                nox: 8,
                luminance: 150,
                dbaInstant: 45,
                dbaAvg: 40,
                dbaPeak: 55,
                sequence: 9,
                mac: "AA:BB:CC:44:55:66"
            )
        )
        XCTAssertEqual(airTag.pm1, 1.1)
        XCTAssertEqual(airTag.pm25, 2.2)
        XCTAssertEqual(airTag.pm4, 4.4)
        XCTAssertEqual(airTag.pm10, 10.1)
        XCTAssertEqual(airTag.co2, 420)
        XCTAssertEqual(airTag.voc, 12)
        XCTAssertEqual(airTag.nox, 8)
        XCTAssertEqual(airTag.luminance, 150)
        XCTAssertEqual(airTag.dbaInstant, 45)
        XCTAssertEqual(airTag.dbaAvg, 40)
        XCTAssertEqual(airTag.dbaPeak, 55)
    }

    func testRuuviTagSensorRecordAndSensorWrappersCoverForwardersAndMutators() {
        let date = Date(timeIntervalSince1970: 100)
        let temperature = Temperature(value: 21.5, unit: .celsius)
        let record = RuuviTagSensorRecordStruct(
            luid: "record-luid".luid,
            date: date,
            source: .advertisement,
            macId: "AA:BB:CC:11:22:33".mac,
            rssi: -62,
            version: 6,
            temperature: temperature,
            humidity: Humidity(value: 0.45, unit: .relative(temperature: temperature)),
            pressure: Pressure(value: 1008.5, unit: .hectopascals),
            acceleration: Acceleration(
                x: Measurement(value: 1, unit: .metersPerSecondSquared),
                y: Measurement(value: 2, unit: .metersPerSecondSquared),
                z: Measurement(value: 3, unit: .metersPerSecondSquared)
            ),
            voltage: Voltage(value: 2.95, unit: .volts),
            movementCounter: 5,
            measurementSequenceNumber: 7,
            txPower: 4,
            pm1: 1.1,
            pm25: 2.2,
            pm4: 3.3,
            pm10: 4.4,
            co2: 600,
            voc: 120,
            nox: 80,
            luminance: 150,
            dbaInstant: 50.2,
            dbaAvg: 55.3,
            dbaPeak: 62.4,
            temperatureOffset: 0.5,
            humidityOffset: 1.5,
            pressureOffset: 2.5
        )
        let any = record.any
        XCTAssertEqual(record.id, "AA:BB:CC:11:22:33100.0")
        XCTAssertEqual(record.uuid, "AA:BB:CC:11:22:33")
        XCTAssertEqual(any.luid?.value, "record-luid")
        XCTAssertEqual(any.date, date)
        XCTAssertEqual(any.source, .advertisement)
        XCTAssertEqual(any.macId?.value, "AA:BB:CC:11:22:33")
        XCTAssertEqual(any.rssi, -62)
        XCTAssertEqual(any.version, 6)
        XCTAssertEqual(any.temperature?.value, 21.5)
        XCTAssertEqual(any.humidity?.value, 0.45)
        XCTAssertEqual(any.pressure?.value, 1008.5)
        XCTAssertEqual(any.acceleration?.x.value, 1)
        XCTAssertEqual(any.voltage?.value, 2.95)
        XCTAssertEqual(any.movementCounter, 5)
        XCTAssertEqual(any.measurementSequenceNumber, 7)
        XCTAssertEqual(any.txPower, 4)
        XCTAssertEqual(any.pm1, 1.1)
        XCTAssertEqual(any.pm25, 2.2)
        XCTAssertEqual(any.pm4, 3.3)
        XCTAssertEqual(any.pm10, 4.4)
        XCTAssertEqual(any.co2, 600)
        XCTAssertEqual(any.voc, 120)
        XCTAssertEqual(any.nox, 80)
        XCTAssertEqual(any.luminance, 150)
        XCTAssertEqual(any.dbaInstant, 50.2)
        XCTAssertEqual(any.dbaAvg, 55.3)
        XCTAssertEqual(any.dbaPeak, 62.4)
        XCTAssertEqual(any.temperatureOffset, 0.5)
        XCTAssertEqual(any.humidityOffset, 1.5)
        XCTAssertEqual(any.pressureOffset, 2.5)
        XCTAssertEqual(Set([any]).count, 1)
        XCTAssertEqual(record.sqlite.pm25, 2.2)
        XCTAssertEqual(record.latest.id, "AA:BB:CC:11:22:33")

        let onlyLuidRecord = RuuviTagSensorRecordStruct(
            luid: "only-luid".luid,
            date: date,
            source: .log,
            macId: nil,
            rssi: nil,
            version: 5,
            temperature: nil,
            humidity: nil,
            pressure: nil,
            acceleration: nil,
            voltage: nil,
            movementCounter: nil,
            measurementSequenceNumber: nil,
            txPower: nil,
            pm1: nil,
            pm25: nil,
            pm4: nil,
            pm10: nil,
            co2: nil,
            voc: nil,
            nox: nil,
            luminance: nil,
            dbaInstant: nil,
            dbaAvg: nil,
            dbaPeak: nil,
            temperatureOffset: 0,
            humidityOffset: 0,
            pressureOffset: 0
        )
        XCTAssertEqual(onlyLuidRecord.id, "only-luid100.0")
        XCTAssertEqual(onlyLuidRecord.uuid, "only-luid")
        XCTAssertEqual(onlyLuidRecord.with(macId: "AA:BB:CC:44:55:66".mac).macId?.value, "AA:BB:CC:44:55:66")
        XCTAssertEqual(record.with(luid: "new-luid".luid).luid?.value, "new-luid")
        XCTAssertEqual(record.with(source: .heartbeat).source, .heartbeat)
        XCTAssertEqual(record.with(sensorSettings: nil).temperatureOffset, 0)
        let adjusted = record.with(sensorSettings: SensorSettingsStruct(
            luid: "settings-luid".luid,
            macId: nil,
            temperatureOffset: 1,
            humidityOffset: 2,
            pressureOffset: 3
        ))
        XCTAssertEqual(adjusted.temperature?.value, 22)
        XCTAssertEqual(adjusted.humidity?.value, 0.95)
        XCTAssertEqual(adjusted.pressure?.value, 1009)

        let updatedAt = Date(timeIntervalSince1970: 200)
        let sensor = RuuviTagSensorStruct(
            version: 5,
            firmwareVersion: "3.31.0+0",
            luid: "sensor-luid".luid,
            macId: "AA:BB:CC:11:22:33".mac,
            serviceUUID: "service",
            isConnectable: true,
            name: "Kitchen",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "pro",
            isCloudSensor: nil,
            canShare: true,
            sharedTo: ["friend@example.com", ""],
            maxHistoryDays: 30,
            lastUpdated: updatedAt
        )
        let anySensor = sensor.any
        XCTAssertEqual(anySensor.version, 5)
        XCTAssertEqual(anySensor.firmwareVersion, "3.31.0+0")
        XCTAssertEqual(anySensor.luid?.value, "sensor-luid")
        XCTAssertEqual(anySensor.macId?.value, "AA:BB:CC:11:22:33")
        XCTAssertEqual(anySensor.serviceUUID, "service")
        XCTAssertEqual(anySensor.isConnectable, true)
        XCTAssertEqual(anySensor.name, "Kitchen")
        XCTAssertEqual(anySensor.isClaimed, true)
        XCTAssertEqual(anySensor.isOwner, true)
        XCTAssertEqual(anySensor.owner, "owner@example.com")
        XCTAssertEqual(anySensor.ownersPlan, "pro")
        XCTAssertEqual(anySensor.isCloudSensor, nil)
        XCTAssertEqual(anySensor.canShare, true)
        XCTAssertEqual(anySensor.sharedTo, ["friend@example.com"])
        XCTAssertEqual(anySensor.maxHistoryDays, 30)
        XCTAssertEqual(anySensor.lastUpdated, updatedAt)
        XCTAssertEqual(anySensor.orderElement, sensor.id)
        XCTAssertEqual(Set([anySensor]).count, 1)
        XCTAssertEqual(sensor.with(version: 6).version, 6)
        XCTAssertEqual(sensor.with(name: "Hallway").name, "Hallway")
        XCTAssertEqual(sensor.with(owner: "new-owner@example.com").owner, "new-owner@example.com")
        XCTAssertEqual(sensor.with(macId: "AA:BB:CC:44:55:66".mac).macId?.value, "AA:BB:CC:44:55:66")
        XCTAssertNil(sensor.withoutOwner().owner)
        XCTAssertNil(sensor.withoutOwner().ownersPlan)
        XCTAssertEqual(sensor.with(luid: "updated-luid".luid).luid?.value, "updated-luid")
        XCTAssertEqual(sensor.unclaimed().ownership, .locallyAddedAndNotClaimed)
        XCTAssertEqual(sensor.with(sharedTo: ["a@example.com"]).sharedTo, ["a@example.com"])
        XCTAssertEqual(sensor.with(canShare: false).canShare, false)
        XCTAssertEqual(sensor.with(maxHistoryDays: 90).maxHistoryDays, 90)
        XCTAssertEqual(sensor.with(lastUpdated: nil).lastUpdated, nil)
        XCTAssertEqual(anySensor, sensor.with(name: "Other").any)
        XCTAssertNotEqual(
            anySensor,
            RuuviTagSensorStruct(
                version: 5,
                firmwareVersion: nil,
                luid: "different-luid".luid,
                macId: "AA:BB:CC:AA:BB:CC".mac,
                serviceUUID: nil,
                isConnectable: false,
                name: "Other",
                isClaimed: false,
                isOwner: false,
                owner: nil,
                ownersPlan: nil,
                isCloudSensor: false,
                canShare: false,
                sharedTo: [],
                maxHistoryDays: nil,
                lastUpdated: nil
            ).any
        )
        XCTAssertFalse(sensor.isCloud)
        XCTAssertTrue(sensor.with(isCloudSensor: true).isCloud)
    }

    func testEnvLogFullMapsDenseValuesIntoSensorRecord() {
        let date = Date(timeIntervalSince1970: 1234)
        let log = RuuviTagEnvLogFull(
            date: date,
            temperature: 21.25,
            humidity: 42.0,
            pressure: 1008.75,
            pm1: 1.1,
            pm25: 2.2,
            pm4: 3.3,
            pm10: 4.4,
            co2: 601,
            voc: 121,
            nox: 81,
            luminosity: 151,
            soundInstant: 50.1,
            soundAvg: 55.2,
            soundPeak: 62.3,
            batteryVoltage: 2.98,
            measurementSequenceNumber: 456
        )

        let record = log.ruuviSensorRecord(uuid: "luid-1", mac: "AA:BB:CC:11:22:33")

        XCTAssertEqual(record.luid?.value, "luid-1")
        XCTAssertEqual(record.date, date)
        XCTAssertEqual(record.source, .log)
        XCTAssertEqual(record.macId?.value, "AA:BB:CC:11:22:33")
        XCTAssertNil(record.rssi)
        XCTAssertEqual(record.version, 0)
        XCTAssertEqual(record.temperature?.value, 21.25)
        XCTAssertEqual(record.temperature?.unit, .celsius)
        XCTAssertEqual(record.humidity?.value ?? .nan, 0.42, accuracy: 0.0001)
        XCTAssertEqual(record.pressure?.value, 1008.75)
        XCTAssertEqual(record.pressure?.unit, .hectopascals)
        XCTAssertNil(record.acceleration)
        XCTAssertEqual(record.voltage?.value, 2.98)
        XCTAssertEqual(record.voltage?.unit, .volts)
        XCTAssertNil(record.movementCounter)
        XCTAssertEqual(record.measurementSequenceNumber, 456)
        XCTAssertNil(record.txPower)
        XCTAssertEqual(record.pm1, 1.1)
        XCTAssertEqual(record.pm25, 2.2)
        XCTAssertEqual(record.pm4, 3.3)
        XCTAssertEqual(record.pm10, 4.4)
        XCTAssertEqual(record.co2, 601)
        XCTAssertEqual(record.voc, 121)
        XCTAssertEqual(record.nox, 81)
        XCTAssertEqual(record.luminance, 151)
        XCTAssertEqual(record.dbaInstant, 50.1)
        XCTAssertEqual(record.dbaAvg, 55.2)
        XCTAssertEqual(record.dbaPeak, 62.3)
        XCTAssertEqual(record.temperatureOffset, 0)
        XCTAssertEqual(record.humidityOffset, 0)
        XCTAssertEqual(record.pressureOffset, 0)
    }

    func testEnvLogFullMapsMissingAndInvalidValuesIntoNilRecordFields() {
        let log = RuuviTagEnvLogFull(
            date: Date(timeIntervalSince1970: 4321),
            temperature: nil,
            humidity: -1,
            pressure: nil,
            pm1: nil,
            pm25: nil,
            pm4: nil,
            pm10: nil,
            co2: nil,
            voc: nil,
            nox: nil,
            luminosity: nil,
            soundInstant: nil,
            soundAvg: nil,
            soundPeak: nil,
            batteryVoltage: nil,
            measurementSequenceNumber: nil
        )

        let record = log.ruuviSensorRecord(uuid: "local-only", mac: nil)

        XCTAssertEqual(record.luid?.value, "local-only")
        XCTAssertNil(record.macId)
        XCTAssertNil(record.temperature)
        XCTAssertNil(record.humidity)
        XCTAssertNil(record.pressure)
        XCTAssertNil(record.acceleration)
        XCTAssertEqual(record.voltage?.value, 0)
        XCTAssertEqual(record.measurementSequenceNumber, nil)
    }

    func testSubscriptionSensorSettingsQueuedRequestAndAccuracyHelpersPreserveValues() {
        let subscription = CloudSensorSubscriptionStruct(
            subscriptionName: "pro",
            isActive: true,
            maxClaims: 3,
            maxHistoryDays: 365,
            maxResolutionMinutes: 5,
            maxShares: 10,
            maxSharesPerSensor: 2,
            delayedAlertAllowed: true,
            emailAlertAllowed: false,
            offlineAlertAllowed: true,
            pdfExportAllowed: true,
            pushAlertAllowed: true,
            telegramAlertAllowed: false,
            endAt: "2099-01-01"
        ).with(macId: "AA:BB:CC:11:22:33")

        XCTAssertEqual(subscription.id, "AA:BB:CC:11:22:33-subscription")
        XCTAssertEqual(subscription.macId, "AA:BB:CC:11:22:33")
        XCTAssertEqual(subscription.subscriptionName, "pro")
        XCTAssertEqual(subscription.maxHistoryDays, 365)

        let settings = SensorSettingsStruct(
            luid: "luid-1".luid,
            macId: nil,
            temperatureOffset: 1.5,
            humidityOffset: 2.5,
            pressureOffset: 3.5,
            description: "Basement",
            displayOrder: ["temperature", "humidity"],
            defaultDisplayOrder: false,
            displayOrderLastUpdated: Date(timeIntervalSince1970: 100),
            defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 200),
            descriptionLastUpdated: Date(timeIntervalSince1970: 300)
        ).with(macId: "AA:BB:CC:11:22:33".mac)

        XCTAssertEqual(settings.id, "AA:BB:CC:11:22:33-settings")
        XCTAssertEqual(settings.luid?.value, "luid-1")
        XCTAssertEqual(settings.description, "Basement")
        XCTAssertEqual(settings.displayOrder ?? [], ["temperature", "humidity"])
        XCTAssertEqual(settings.defaultDisplayOrder, false)

        let request = RuuviCloudQueuedRequestStruct(
            id: 42,
            type: .uploadImage,
            status: .failed,
            uniqueKey: "unique",
            requestDate: Date(timeIntervalSince1970: 10),
            successDate: Date(timeIntervalSince1970: 20),
            attempts: 1,
            requestBodyData: Data([0x01]),
            additionalData: Data([0x02])
        ).with(attempts: 3)

        XCTAssertEqual(request.id, 42)
        XCTAssertEqual(request.type, .uploadImage)
        XCTAssertEqual(request.status, .failed)
        XCTAssertEqual(request.uniqueKey, "unique")
        XCTAssertEqual(request.attempts, 3)
        XCTAssertEqual(request.requestBodyData, Data([0x01]))
        XCTAssertEqual(request.additionalData, Data([0x02]))

        XCTAssertEqual(MeasurementAccuracyType.zero.value, 0)
        XCTAssertEqual(MeasurementAccuracyType.zero.displayValue, 1.0)
        XCTAssertEqual(MeasurementAccuracyType.one.value, 1)
        XCTAssertEqual(MeasurementAccuracyType.one.displayValue, 0.1)
        XCTAssertEqual(MeasurementAccuracyType.two.value, 2)
        XCTAssertEqual(MeasurementAccuracyType.two.displayValue, 0.01)
        XCTAssertEqual(OffsetCorrectionType.temperature.rawValue, 0)
        XCTAssertEqual(OffsetCorrectionType.humidity.rawValue, 1)
        XCTAssertEqual(OffsetCorrectionType.pressure.rawValue, 2)
    }

    func testLocationBranchesCoverSingleFieldFallbacks() {
        XCTAssertEqual(
            CoverageLocation(city: "Helsinki", state: nil, country: nil).cityCommaCountry,
            "Helsinki"
        )
        XCTAssertEqual(
            CoverageLocation(city: nil, state: nil, country: "Finland").cityCommaCountry,
            "Finland"
        )
        XCTAssertNil(CoverageLocation(city: nil, state: nil, country: nil).cityCommaCountry)

        XCTAssertEqual(
            CoverageLocation(city: "Helsinki", state: nil, country: nil).description,
            "Helsinki"
        )
        XCTAssertEqual(
            CoverageLocation(city: nil, state: "Uusimaa", country: nil).description,
            "Uusimaa"
        )
        XCTAssertNil(CoverageLocation(city: nil, state: nil, country: nil).description)
    }

    func testAnyCloudSensorDenseForwardsRecordAndSubscriptionProperties() {
        let sensor = CloudSensorStruct(
            id: "AA:BB:CC:11:22:33",
            serviceUUID: "service",
            name: "Kitchen",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "ignored-by-dense",
            picture: URL(string: "https://example.com/sensor.png"),
            offsetTemperature: 1.5,
            offsetHumidity: 2.5,
            offsetPressure: 3.5,
            isCloudSensor: true,
            canShare: true,
            sharedTo: ["friend@example.com"],
            maxHistoryDays: 30,
            lastUpdated: Date(timeIntervalSince1970: 400)
        )
        let record = makeDenseRecord(macId: sensor.id)
        let subscription = CloudSensorSubscriptionStruct(
            macId: sensor.id,
            subscriptionName: "business",
            isActive: true,
            maxClaims: 3,
            maxHistoryDays: 365,
            maxResolutionMinutes: 5,
            maxShares: 10,
            maxSharesPerSensor: 2,
            delayedAlertAllowed: true,
            emailAlertAllowed: true,
            offlineAlertAllowed: true,
            pdfExportAllowed: true,
            pushAlertAllowed: true,
            telegramAlertAllowed: false,
            endAt: "2099-01-01"
        )
        let dense = AnyCloudSensorDense(
            sensor: sensor,
            record: record,
            subscription: subscription
        )
        let denseWithoutSubscription = AnyCloudSensorDense(
            sensor: sensor,
            record: record,
            subscription: nil
        )

        XCTAssertEqual(dense.id, sensor.id)
        XCTAssertEqual(dense.serviceUUID, "service")
        XCTAssertEqual(dense.name, "Kitchen")
        XCTAssertEqual(dense.owner, "owner@example.com")
        XCTAssertEqual(dense.ownersPlan, "business")
        XCTAssertEqual(dense.picture, sensor.picture)
        XCTAssertEqual(dense.offsetTemperature, 1.5)
        XCTAssertEqual(dense.offsetHumidity, 2.5)
        XCTAssertEqual(dense.offsetPressure, 3.5)
        XCTAssertEqual(dense.isCloudSensor, true)
        XCTAssertEqual(dense.canShare, true)
        XCTAssertEqual(dense.sharedTo, ["friend@example.com"])
        XCTAssertEqual(dense.maxHistoryDays, 365)
        XCTAssertEqual(dense.lastUpdated, sensor.lastUpdated)
        XCTAssertEqual(dense.orderElement, sensor.id)
        XCTAssertEqual(denseWithoutSubscription.ownersPlan, nil)
        XCTAssertEqual(denseWithoutSubscription.maxHistoryDays, nil)

        XCTAssertEqual(dense.luid?.value, "luid-1")
        XCTAssertEqual(dense.date, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(dense.source, .advertisement)
        XCTAssertEqual(dense.macId?.value, sensor.id)
        XCTAssertEqual(dense.rssi, -62)
        XCTAssertEqual(dense.temperature?.value, 21.5)
        XCTAssertEqual(dense.humidity?.value, 0.45)
        XCTAssertEqual(dense.pressure?.value, 1008.5)
        XCTAssertEqual(dense.acceleration?.x.value, 1)
        XCTAssertEqual(dense.acceleration?.y.value, 2)
        XCTAssertEqual(dense.acceleration?.z.value, 3)
        XCTAssertEqual(dense.voltage?.value, 2.95)
        XCTAssertEqual(dense.movementCounter, 5)
        XCTAssertEqual(dense.measurementSequenceNumber, 7)
        XCTAssertEqual(dense.txPower, 4)
        XCTAssertEqual(dense.pm1, 1.1)
        XCTAssertEqual(dense.pm25, 2.2)
        XCTAssertEqual(dense.pm4, 3.3)
        XCTAssertEqual(dense.pm10, 4.4)
        XCTAssertEqual(dense.co2, 600)
        XCTAssertEqual(dense.voc, 120)
        XCTAssertEqual(dense.nox, 80)
        XCTAssertEqual(dense.luminance, 150)
        XCTAssertEqual(dense.dbaInstant, 50.2)
        XCTAssertEqual(dense.dbaAvg, 55.3)
        XCTAssertEqual(dense.dbaPeak, 62.4)
        XCTAssertEqual(dense.temperatureOffset, 0)
        XCTAssertEqual(dense.humidityOffset, 0)
        XCTAssertEqual(dense.pressureOffset, 0)
        XCTAssertEqual(dense.version, 5)
        XCTAssertEqual(dense.isClaimed, true)
        XCTAssertEqual(dense.isOwner, true)
        XCTAssertEqual(Set([dense]).count, 1)
    }

}

private struct ReorderableString: Reorderable {
    let id: String

    var orderElement: String {
        id
    }
}

private struct CoverageLocation: Location {
    let city: String?
    let state: String?
    let country: String?
    let coordinate = CLLocationCoordinate2D(latitude: 60.1699, longitude: 24.9384)
}

private func makeDenseRecord(macId: String) -> RuuviTagSensorRecord {
    let temperature = Temperature(value: 21.5, unit: .celsius)
    return RuuviTagSensorRecordStruct(
        luid: "luid-1".luid,
        date: Date(timeIntervalSince1970: 100),
        source: .advertisement,
        macId: macId.mac,
        rssi: -62,
        version: 5,
        temperature: temperature,
        humidity: Humidity(value: 0.45, unit: .relative(temperature: temperature)),
        pressure: Pressure(value: 1008.5, unit: .hectopascals),
        acceleration: Acceleration(
            x: Measurement(value: 1, unit: .metersPerSecondSquared),
            y: Measurement(value: 2, unit: .metersPerSecondSquared),
            z: Measurement(value: 3, unit: .metersPerSecondSquared)
        ),
        voltage: Voltage(value: 2.95, unit: .volts),
        movementCounter: 5,
        measurementSequenceNumber: 7,
        txPower: 4,
        pm1: 1.1,
        pm25: 2.2,
        pm4: 3.3,
        pm10: 4.4,
        co2: 600,
        voc: 120,
        nox: 80,
        luminance: 150,
        dbaInstant: 50.2,
        dbaAvg: 55.3,
        dbaPeak: 62.4,
        temperatureOffset: 0,
        humidityOffset: 0,
        pressureOffset: 0
    )
}
