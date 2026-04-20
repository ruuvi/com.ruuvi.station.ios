@testable import RuuviLocal
@testable import RuuviService
import BTKit
import Humidity
import RuuviCloud
import RuuviLocalization
import RuuviOntology
import XCTest

final class RuuviServiceCoverageTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetTestUserDefaults()
    }

    func testAppSettingsForwardsRemainingCloudBackedValues() async throws {
        let cloud = CloudSpy()
        let settings = makeSettings()
        let sut = RuuviServiceAppSettingsImpl(cloud: cloud, localSettings: settings)

        let temperatureAccuracy = try await sut.set(temperatureAccuracy: .one)
        let humidityUnit = try await sut.set(humidityUnit: .dew)
        let humidityAccuracy = try await sut.set(humidityAccuracy: .zero)
        let pressureUnit = try await sut.set(pressureUnit: .inchesOfMercury)
        let pressureAccuracy = try await sut.set(pressureAccuracy: .one)
        let marketingPreference = try await sut.set(marketingPreference: true)

        XCTAssertEqual(temperatureAccuracy, .one)
        XCTAssertEqual(humidityUnit, .dew)
        XCTAssertEqual(humidityAccuracy, .zero)
        XCTAssertEqual(pressureUnit, .inchesOfMercury)
        XCTAssertEqual(pressureAccuracy, .one)
        XCTAssertTrue(marketingPreference)

        XCTAssertEqual(settings.temperatureAccuracy, .one)
        XCTAssertEqual(settings.humidityUnit, .dew)
        XCTAssertEqual(settings.humidityAccuracy, .zero)
        XCTAssertEqual(settings.pressureUnit, .inchesOfMercury)
        XCTAssertEqual(settings.pressureAccuracy, .one)
        XCTAssertTrue(settings.marketingPreference)
        XCTAssertEqual(cloud.setTemperatureAccuracies, [.one])
        XCTAssertEqual(cloud.setHumidityUnits, [.dew])
        XCTAssertEqual(cloud.setHumidityAccuracies, [.zero])
        XCTAssertEqual(cloud.setPressureUnits, [.inchesOfMercury])
        XCTAssertEqual(cloud.setPressureAccuracies, [.one])
        XCTAssertEqual(cloud.setMarketingPreferenceValues, [true])
    }

    func testAppSettingsForwardsRemainingRemoteOnlySettings() async throws {
        let cloud = CloudSpy()
        let sut = RuuviServiceAppSettingsImpl(cloud: cloud, localSettings: makeSettings())

        let showAllData = try await sut.set(showAllData: true)
        let drawDots = try await sut.set(drawDots: false)
        let chartDuration = try await sut.set(chartDuration: 14)
        let showMinMaxAvg = try await sut.set(showMinMaxAvg: true)
        let cloudMode = try await sut.set(cloudMode: true)
        let dashboard = try await sut.set(dashboard: true)
        let dashboardType = try await sut.set(dashboardType: .simple)
        let dashboardTapActionType = try await sut.set(dashboardTapActionType: .chart)
        let disableEmailAlert = try await sut.set(disableEmailAlert: true)
        let disablePushAlert = try await sut.set(disablePushAlert: true)
        let profileLanguageCode = try await sut.set(profileLanguageCode: "sv")

        XCTAssertTrue(showAllData)
        XCTAssertFalse(drawDots)
        XCTAssertEqual(chartDuration, 14)
        XCTAssertTrue(showMinMaxAvg)
        XCTAssertTrue(cloudMode)
        XCTAssertTrue(dashboard)
        XCTAssertEqual(dashboardType, .simple)
        XCTAssertEqual(dashboardTapActionType, .chart)
        XCTAssertTrue(disableEmailAlert)
        XCTAssertTrue(disablePushAlert)
        XCTAssertEqual(profileLanguageCode, "sv")

        XCTAssertEqual(cloud.setShowAllDataValues, [true])
        XCTAssertEqual(cloud.setDrawDotsValues, [false])
        XCTAssertEqual(cloud.setChartDurationValues, [14])
        XCTAssertEqual(cloud.setShowMinMaxAvgValues, [true])
        XCTAssertEqual(cloud.setCloudModeValues, [true])
        XCTAssertEqual(cloud.setDashboardValues, [true])
        XCTAssertEqual(cloud.setDashboardTypeValues, [.simple])
        XCTAssertEqual(cloud.setDashboardTapActionTypeValues, [.chart])
        XCTAssertEqual(cloud.setDisableEmailAlertValues, [true])
        XCTAssertEqual(cloud.setDisablePushAlertValues, [true])
        XCTAssertEqual(cloud.setProfileLanguageCodeValues, ["sv"])
    }

    func testCloudNotificationRefreshesWhenTokenWasNeverRefreshedAndSkipsUnauthorizedSoundUpdate() async throws {
        let cloud = CloudSpy()
        cloud.registerPNTokenResult = 123
        let user = UserSpy()
        user.isAuthorized = true
        let pnManager = PNManagerSpy()
        pnManager.fcmTokenId = 7
        pnManager.fcmTokenLastRefreshed = nil
        let sut = RuuviServiceCloudNotificationImpl(
            cloud: cloud,
            pool: PoolSpy(),
            storage: StorageSpy(),
            ruuviUser: user,
            pnManager: pnManager
        )

        let tokenId = try await sut.set(
            token: "new-token",
            name: "Phone",
            data: nil,
            language: .english,
            sound: .systemDefault
        )

        XCTAssertEqual(tokenId, 123)
        XCTAssertEqual(cloud.registeredPNTokens.count, 1)
        XCTAssertEqual(pnManager.fcmTokenId, 123)
        XCTAssertEqual(pnManager.fcmToken, "new-token")
        XCTAssertNotNil(pnManager.fcmTokenLastRefreshed)

        user.isAuthorized = false
        pnManager.fcmTokenId = 321
        pnManager.fcmToken = "stored-token"

        let unauthorizedTokenId = try await sut.set(
            sound: .systemDefault,
            language: .english,
            deviceName: "Phone"
        )

        XCTAssertEqual(unauthorizedTokenId, 321)
        XCTAssertEqual(cloud.registeredPNTokens.count, 1)
    }

    func testCloudNotificationReturnsZeroWhenStoredTokenIdIsMissing() async throws {
        let cloud = CloudSpy()
        let user = UserSpy()
        let pnManager = PNManagerSpy()
        let sut = RuuviServiceCloudNotificationImpl(
            cloud: cloud,
            pool: PoolSpy(),
            storage: StorageSpy(),
            ruuviUser: user,
            pnManager: pnManager
        )

        let unauthorizedTokenId = try await sut.set(
            token: "token",
            name: "Phone",
            data: nil,
            language: .english,
            sound: .systemDefault
        )
        user.isAuthorized = true
        pnManager.fcmTokenId = nil
        pnManager.fcmTokenLastRefreshed = Date()
        let freshTokenId = try await sut.set(
            token: "token",
            name: "Phone",
            data: nil,
            language: .english,
            sound: .systemDefault
        )
        pnManager.fcmToken = nil
        let missingStoredTokenId = try await sut.set(
            sound: .systemDefault,
            language: .english,
            deviceName: "Phone"
        )

        XCTAssertEqual(unauthorizedTokenId, 0)
        XCTAssertEqual(freshTokenId, 0)
        XCTAssertEqual(missingStoredTokenId, 0)
        XCTAssertTrue(cloud.registeredPNTokens.isEmpty)
    }

    func testAuthLogoutSucceedsWithoutClaimedOrCloudSensors() async throws {
        let storage = StorageSpy()
        storage.readAllResult = []
        let user = UserSpy()
        let settings = makeSettings()
        let sut = RuuviServiceAuthImpl(
            ruuviUser: user,
            pool: PoolSpy(),
            storage: storage,
            propertiesService: SensorPropertiesSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            alertService: RuuviServiceAlertImpl(
                cloud: CloudSpy(),
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: settings
            ),
            settings: settings
        )
        let willLogout = expectation(forNotification: .RuuviAuthServiceWillLogout, object: nil)
        let didFinish = expectation(forNotification: .RuuviAuthServiceLogoutDidFinish, object: nil) { note in
            note.userInfo?[RuuviAuthServiceLogoutDidFinishKey.success] as? Bool == true
        }
        let didLogout = expectation(forNotification: .RuuviAuthServiceDidLogout, object: nil)

        let result = try await sut.logout()

        XCTAssertTrue(result)
        XCTAssertEqual(user.logoutCallCount, 1)
        await fulfillment(of: [willLogout, didFinish, didLogout], timeout: 1)
    }

    func testAuthLogoutIgnoresUnclaimedLocalSensors() async throws {
        let storage = StorageSpy()
        storage.readAllResult = [makeSensor(isCloud: false, isClaimed: false).any]
        let pool = PoolSpy()
        let user = UserSpy()
        let settings = makeSettings()
        let sut = RuuviServiceAuthImpl(
            ruuviUser: user,
            pool: pool,
            storage: storage,
            propertiesService: SensorPropertiesSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            alertService: RuuviServiceAlertImpl(
                cloud: CloudSpy(),
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: settings
            ),
            settings: settings
        )

        let result = try await sut.logout()

        XCTAssertTrue(result)
        XCTAssertEqual(user.logoutCallCount, 1)
        XCTAssertTrue(pool.deletedSensors.isEmpty)
        XCTAssertEqual(pool.deleteQueuedRequestsCallCount, 0)
    }

    func testOwnershipClaimAndContestRequireAuthorizedUserEmail() async {
        let user = UserSpy()
        user.email = nil
        let settings = makeSettings()
        let localIDs = RuuviLocalIDsUserDefaults()
        let sut = RuuviServiceOwnershipImpl(
            cloud: CloudSpy(),
            pool: PoolSpy(),
            propertiesService: SensorPropertiesSpy(),
            localIDs: localIDs,
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: CloudSpy(),
                localIDs: localIDs,
                ruuviLocalSettings: settings
            ),
            ruuviUser: user,
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: settings
        )
        let sensor = makeSensor()

        do {
            _ = try await sut.claim(sensor: sensor)
            XCTFail("Expected claim to require authorization")
        } catch let error as RuuviServiceError {
            guard case .ruuviCloud(.notAuthorized) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await sut.contest(sensor: sensor, secret: "secret")
            XCTFail("Expected contest to require authorization")
        } catch let error as RuuviServiceError {
            guard case .ruuviCloud(.notAuthorized) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOwnershipUnclaimRequiresMacId() async {
        let settings = makeSettings()
        let sut = RuuviServiceOwnershipImpl(
            cloud: CloudSpy(),
            pool: PoolSpy(),
            propertiesService: SensorPropertiesSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: CloudSpy(),
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: settings
            ),
            ruuviUser: UserSpy(),
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: settings
        )

        do {
            _ = try await sut.unclaim(sensor: makeSensor(macId: nil), removeCloudHistory: false)
            XCTFail("Expected unclaim to require mac id")
        } catch let error as RuuviServiceError {
            guard case .macIdIsNil = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOwnershipClaimIgnoresGeneratedBackgroundWhenJpegDataIsUnavailable() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let properties = SensorPropertiesSpy()
        properties.getImageResult = UIImage()
        let user = UserSpy()
        user.email = "owner@example.com"
        let settings = makeSettings()
        let sut = RuuviServiceOwnershipImpl(
            cloud: cloud,
            pool: pool,
            propertiesService: properties,
            localIDs: RuuviLocalIDsUserDefaults(),
            localImages: LocalImagesSpy(),
            storage: StorageSpy(),
            alertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: settings
            ),
            ruuviUser: user,
            localSyncState: RuuviLocalSyncStateUserDefaults(),
            settings: settings
        )
        let sensor = makeSensor(macId: "AA:BB:CC:11:22:83")

        let result = try await sut.claim(sensor: sensor)

        XCTAssertEqual(result.id, sensor.id)
        XCTAssertEqual(cloud.claimCalls.first?.1, sensor.id)
        XCTAssertTrue(cloud.uploadCalls.isEmpty)
        XCTAssertTrue(pool.updatedSensors.contains { $0.isCloud && $0.owner == user.email })
    }

    func testMeasurementProtocolExtensionsAndLanguageMappings() {
        let measurement: RuuviServiceMeasurement = RuuviServiceMeasurementImpl(
            settings: makeSettings(),
            emptyValueString: "-",
            percentString: "%"
        )

        XCTAssertNil(measurement.double(for: nil as Temperature?))
        XCTAssertNil(
            measurement.double(
                for: nil as Humidity?,
                temperature: Temperature(value: 21, unit: .celsius),
                isDecimal: true
            )
        )
        XCTAssertNil(measurement.double(for: nil as Pressure?))
        XCTAssertNil(measurement.double(for: nil as Voltage?))
        XCTAssertEqual(Language.english.locale.identifier, "en_US")
        XCTAssertEqual(Language.russian.locale.identifier, "ru_RU")
        XCTAssertEqual(Language.finnish.humidityLanguage, .fi)
        XCTAssertEqual(Language.russian.humidityLanguage, .ru)
        XCTAssertEqual(Language.swedish.humidityLanguage, .sv)
        XCTAssertEqual(Language.german.humidityLanguage, .en)
    }

    func testMeasurementProtocolExtensionsCoverNonNilOptionalsAndRemainingLocales() {
        let measurement: RuuviServiceMeasurement = RuuviServiceMeasurementImpl(
            settings: makeSettings(),
            emptyValueString: "-",
            percentString: "%"
        )
        let temperature = Temperature(value: 21.5, unit: .celsius)
        let humidity = Humidity(value: 0.45, unit: .relative(temperature: temperature))
        let pressure = Pressure(value: 1008.2, unit: .hectopascals)
        let voltage = Voltage(value: 2.95, unit: .volts)

        XCTAssertEqual(measurement.double(for: temperature), 21.5, accuracy: 0.001)
        XCTAssertNotNil(measurement.double(for: humidity, temperature: temperature, isDecimal: true))
        XCTAssertEqual(measurement.double(for: pressure), 1008.2, accuracy: 0.001)
        XCTAssertEqual(measurement.double(for: voltage), 2.95, accuracy: 0.001)
        XCTAssertEqual(Language.french.locale.identifier, "fr")
        XCTAssertEqual(Language.german.locale.identifier, "de")
        XCTAssertEqual(Language.english.humidityLanguage, .en)
        XCTAssertEqual(Language.french.humidityLanguage, .en)
    }

    func testMeasurementSettingsUnitInitializerStoresProvidedUnits() {
        let units = RuuviServiceMeasurementSettingsUnit(
            temperatureUnit: .fahrenheit,
            humidityUnit: .dew,
            pressureUnit: .inchesOfMercury
        )

        XCTAssertEqual(units.temperatureUnit, .fahrenheit)
        XCTAssertEqual(units.humidityUnit, .dew)
        XCTAssertEqual(units.pressureUnit, .inchesOfMercury)
    }

    func testSensorPropertiesConvenienceOverloadForwardsNilProgress() async throws {
        let spy = SensorPropertiesSpy()
        let service: RuuviServiceSensorProperties = spy
        let sensor = makeSensor()

        let url = try await service.set(
            image: makeImage(color: .blue),
            for: sensor,
            maxSize: CGSize(width: 64, height: 48),
            compressionQuality: 0.65
        )

        XCTAssertEqual(url.lastPathComponent, "sensor.jpg")
        XCTAssertEqual(spy.setImageCalls.count, 1)
        XCTAssertEqual(spy.setImageCalls.first?.sensorID, sensor.id)
        XCTAssertFalse(spy.setImageCalls.first?.progressWasProvided == true)
        XCTAssertEqual(spy.setImageCalls.first?.maxSize, CGSize(width: 64, height: 48))
        XCTAssertEqual(
            try XCTUnwrap(spy.setImageCalls.first?.compressionQuality),
            CGFloat(0.65),
            accuracy: 0.0001
        )
    }

    func testMeasurementFormatsHumidityPressureVoltageAndQualityHelpers() {
        let settings = makeSettings()
        settings.temperatureUnit = .fahrenheit
        settings.humidityUnit = .gm3
        settings.pressureUnit = .newtonsPerMetersSquared
        let sut = RuuviServiceMeasurementImpl(
            settings: settings,
            emptyValueString: "-",
            percentString: "%"
        )
        let temperature = Temperature(value: 22, unit: .celsius)
        let humidity = Humidity(value: 0.52, unit: .relative(temperature: temperature))
        let pressure = Pressure(value: 1013.2, unit: .hectopascals)
        let voltage = Voltage(value: 2.89, unit: .volts)

        XCTAssertNotNil(sut.double(for: humidity, temperature: temperature, isDecimal: false))
        XCTAssertFalse(
            sut.string(for: humidity, temperature: temperature, allowSettings: true).isEmpty
        )
        XCTAssertTrue(
            sut.string(
                for: humidity,
                temperature: temperature,
                allowSettings: true,
                unit: .dew
            ).contains(settings.temperatureUnit.symbol)
        )
        XCTAssertEqual(sut.double(for: pressure), 101_320)
        XCTAssertEqual(sut.stringWithoutSign(for: pressure), "101320")
        XCTAssertFalse(sut.string(for: voltage).isEmpty)
        XCTAssertFalse(sut.temperatureOffsetCorrectionString(for: 1.5).isEmpty)
        XCTAssertFalse(sut.pressureOffsetCorrectionString(for: 2.5).isEmpty)
        XCTAssertFalse(sut.humidityOffsetCorrectionString(for: 0.25).isEmpty)
        XCTAssertEqual(sut.string(for: 12.345), "12.35")
        XCTAssertEqual(sut.string(from: 12.345), "12.34")
        XCTAssertEqual(sut.double(for: 4.567), 4.57)
        XCTAssertEqual(sut.double(for: nil), 0)
        XCTAssertEqual(sut.aqi(for: nil, pm25: 10).currentScore, 0)
        XCTAssertEqual(sut.aqi(for: 600, and: 10), 80.8)

        let co2State = sut.co2(for: 1_600)
        guard case .poor = co2State.state else {
            return XCTFail("Expected poor CO2 state")
        }
        let pm25State = sut.pm25(for: 60)
        guard case .veryPoor = pm25State.state else {
            return XCTFail("Expected very poor PM2.5 state")
        }
        XCTAssertEqual(sut.aqiString(for: 45.6), "46")
        XCTAssertEqual(
            sut.co2String(for: 1234.9)
                .replacingOccurrences(of: Locale.autoupdatingCurrent.groupingSeparator ?? ",", with: ""),
            "1234"
        )
        XCTAssertEqual(sut.pm10String(for: 12.5), "12.5")
        XCTAssertEqual(sut.pm25String(for: 22.5), "22.5")
        XCTAssertEqual(sut.pm40String(for: 32.5), "32.5")
        XCTAssertEqual(sut.pm100String(for: 42.5), "42.5")
        XCTAssertEqual(sut.vocString(for: 87.9), "87")
        XCTAssertEqual(sut.noxString(for: 45.6), "45")
        XCTAssertEqual(sut.soundString(for: 64.2), "64")
        XCTAssertEqual(sut.luminosityString(for: 150.9), "150")
    }

    func testMeasurementCoversRemainingFormattingAndSettingsBranches() {
        func localizedDouble(_ string: String) -> Double? {
            let normalized = string.replacingOccurrences(
                of: Locale.current.decimalSeparator ?? ",",
                with: "."
            )
            return Double(normalized)
        }

        let baseSettings = makeSettings()
        let sut = RuuviServiceMeasurementImpl(
            settings: baseSettings,
            emptyValueString: "-",
            percentString: "%"
        )
        let temperature = Temperature(value: 21.239, unit: .celsius)
        let humidity = Humidity(
            value: 0.52,
            unit: .relative(temperature: Temperature(value: 22, unit: .celsius))
        )

        XCTAssertEqual(sut.double(for: temperature), 21.24, accuracy: 0.001)
        XCTAssertEqual(localizedDouble(sut.stringWithoutSign(for: temperature)) ?? 0, 21.24, accuracy: 0.01)
        XCTAssertEqual(localizedDouble(sut.stringWithoutSign(temperature: 21.239)) ?? 0, 21.24, accuracy: 0.01)
        XCTAssertEqual(localizedDouble(sut.stringWithoutSign(humidity: 52.129)) ?? 0, 52.13, accuracy: 0.01)
        XCTAssertEqual(sut.double(for: Voltage(value: 2.891, unit: .volts)), 2.89, accuracy: 0.001)
        XCTAssertTrue(sut.aqi(for: nil, and: 12).isNaN)
        XCTAssertEqual(0.0.stringValue, "0")
        XCTAssertEqual(12.3.formattedStringValue(places: 1), "12.3")

        let imperialSettings = makeSettings()
        imperialSettings.pressureUnit = .inchesOfMercury
        let imperialSut = RuuviServiceMeasurementImpl(
            settings: imperialSettings,
            emptyValueString: "-",
            percentString: "%"
        )
        let pressure = Pressure(value: 1013.25, unit: .hectopascals)
        XCTAssertFalse(imperialSut.string(for: pressure, allowSettings: true).isEmpty)
        XCTAssertFalse(imperialSut.stringWithoutSign(for: pressure).isEmpty)
        XCTAssertFalse(imperialSut.stringWithoutSign(pressure: imperialSut.double(for: pressure)).isEmpty)

        let pascalSettings = makeSettings()
        pascalSettings.pressureUnit = .newtonsPerMetersSquared
        let pascalSut = RuuviServiceMeasurementImpl(
            settings: pascalSettings,
            emptyValueString: "-",
            percentString: "%"
        )
        XCTAssertEqual(pascalSut.double(for: pressure), 101_325)
        XCTAssertEqual(pascalSut.stringWithoutSign(for: pressure), "101325")

        let absoluteHumiditySettings = makeSettings()
        absoluteHumiditySettings.humidityUnit = .gm3
        let absoluteHumiditySut = RuuviServiceMeasurementImpl(
            settings: absoluteHumiditySettings,
            emptyValueString: "-",
            percentString: "%"
        )
        XCTAssertFalse(
            absoluteHumiditySut.stringWithoutSign(
                for: humidity,
                temperature: Temperature(value: 22, unit: .celsius)
            ).isEmpty
        )

        let dewPointSettings = makeSettings()
        dewPointSettings.humidityUnit = .dew
        let dewPointSut = RuuviServiceMeasurementImpl(
            settings: dewPointSettings,
            emptyValueString: "-",
            percentString: "%"
        )
        XCTAssertFalse(
            dewPointSut.stringWithoutSign(
                for: humidity,
                temperature: Temperature(value: 22, unit: .celsius)
            ).isEmpty
        )

        let updatedSettings = makeSettings()
        updatedSettings.temperatureUnit = .fahrenheit
        updatedSettings.humidityUnit = .dew
        updatedSettings.pressureUnit = .inchesOfMercury
        sut.settings = updatedSettings

        XCTAssertEqual(sut.units.temperatureUnit, .fahrenheit)
        XCTAssertEqual(sut.units.humidityUnit, .dew)
        XCTAssertEqual(sut.units.pressureUnit, .inchesOfMercury)
    }

    func testMeasurementCoversNilFormattingAndAirQualityBoundaries() {
        func stateLabel(_ state: MeasurementQualityState) -> String {
            switch state {
            case .excellent:
                return "excellent"
            case .good:
                return "good"
            case .fair:
                return "fair"
            case .poor:
                return "poor"
            case .veryPoor:
                return "veryPoor"
            case .undefined:
                return "undefined"
            }
        }

        func localizedDouble(_ string: String) -> Double? {
            let normalized = string.replacingOccurrences(
                of: Locale.current.decimalSeparator ?? ",",
                with: "."
            )
            return Double(normalized)
        }

        let sut = RuuviServiceMeasurementImpl(
            settings: makeSettings(),
            emptyValueString: "-",
            percentString: "%"
        )
        let temperature = Temperature(value: 20, unit: .celsius)
        let humidity = Humidity(value: 0.45, unit: .relative(temperature: temperature))

        XCTAssertEqual(sut.stringWithoutSign(for: nil as Temperature?), "-")
        XCTAssertEqual(sut.stringWithoutSign(temperature: nil), "-")
        XCTAssertEqual(sut.stringWithoutSign(for: nil as Pressure?), "-")
        XCTAssertEqual(sut.stringWithoutSign(pressure: nil), "-")
        XCTAssertEqual(sut.string(for: nil as Voltage?), "-")
        XCTAssertEqual(sut.stringWithoutSign(for: nil as Humidity?, temperature: temperature), "-")
        XCTAssertEqual(sut.stringWithoutSign(for: humidity, temperature: nil), "-")
        XCTAssertEqual(sut.stringWithoutSign(humidity: nil), "-")
        XCTAssertEqual(sut.string(from: nil), "")
        XCTAssertEqual(sut.aqiString(for: nil), "-")
        XCTAssertEqual(sut.co2String(for: nil), "-")
        XCTAssertEqual(sut.pm10String(for: nil), "-")
        XCTAssertEqual(sut.pm25String(for: nil), "-")
        XCTAssertEqual(sut.pm40String(for: nil), "-")
        XCTAssertEqual(sut.pm100String(for: nil), "-")
        XCTAssertEqual(sut.vocString(for: nil), "-")
        XCTAssertEqual(sut.noxString(for: nil), "-")
        XCTAssertEqual(sut.soundString(for: nil), "-")
        XCTAssertEqual(sut.luminosityString(for: nil), "-")
        XCTAssertFalse(sut.string(for: temperature, allowSettings: true).isEmpty)
        XCTAssertFalse(sut.string(for: temperature, allowSettings: false).isEmpty)
        XCTAssertEqual(localizedDouble(sut.stringWithoutSign(for: humidity, temperature: temperature)) ?? 0, 45, accuracy: 0.01)

        XCTAssertEqual(stateLabel(sut.co2(for: nil).state), "excellent")
        XCTAssertEqual(stateLabel(sut.co2(for: 300).state), "excellent")
        XCTAssertEqual(stateLabel(sut.co2(for: 500).state), "excellent")
        XCTAssertEqual(stateLabel(sut.co2(for: 700).state), "good")
        XCTAssertEqual(stateLabel(sut.co2(for: 1_000).state), "fair")
        XCTAssertEqual(stateLabel(sut.co2(for: 1_600).state), "poor")
        XCTAssertEqual(stateLabel(sut.co2(for: 2_200).state), "veryPoor")
        XCTAssertEqual(stateLabel(sut.co2(for: -1).state), "excellent")

        XCTAssertEqual(stateLabel(sut.pm25(for: nil).state), "excellent")
        XCTAssertEqual(stateLabel(sut.pm25(for: 2).state), "excellent")
        XCTAssertEqual(stateLabel(sut.pm25(for: 7).state), "good")
        XCTAssertEqual(stateLabel(sut.pm25(for: 20).state), "fair")
        XCTAssertEqual(stateLabel(sut.pm25(for: 40).state), "poor")
        XCTAssertEqual(stateLabel(sut.pm25(for: 70).state), "veryPoor")
        XCTAssertEqual(stateLabel(sut.pm25(for: -1).state), "excellent")

        XCTAssertEqual(stateLabel(sut.aqi(for: 420, pm25: 0).state), "excellent")
        XCTAssertEqual(stateLabel(sut.aqi(for: 420, pm25: 9).state), "good")
        XCTAssertEqual(stateLabel(sut.aqi(for: 420, pm25: 20).state), "fair")
        XCTAssertEqual(stateLabel(sut.aqi(for: 420, pm25: 40).state), "poor")
        XCTAssertEqual(stateLabel(sut.aqi(for: 420, pm25: 60).state), "veryPoor")
    }

    func testMeasurementCoversOptionalExtensionAndRemainingFormattingBranches() {
        let temperature = Temperature(value: 20.5, unit: .celsius)
        let humidity = Humidity(value: 0.45, unit: .relative(temperature: temperature))
        let pressure = Pressure(value: 1013.25, unit: .hectopascals)
        let voltage = Voltage(value: 2.95, unit: .volts)
        let settings = makeSettings()
        let sut = RuuviServiceMeasurementImpl(
            settings: settings,
            emptyValueString: "-",
            percentString: "%"
        )
        let protocolSut: RuuviServiceMeasurement = sut
        XCTAssertEqual(
            protocolSut.double(for: temperature as Temperature?) ?? .nan,
            20.5,
            accuracy: 0.001
        )
        XCTAssertNotNil(
            protocolSut.double(
                for: humidity as Humidity?,
                temperature: temperature as Temperature?,
                isDecimal: true
            )
        )
        XCTAssertEqual(
            protocolSut.double(for: pressure as Pressure?) ?? .nan,
            1013.25,
            accuracy: 0.001
        )
        XCTAssertEqual(
            protocolSut.double(for: voltage as Voltage?) ?? .nan,
            2.95,
            accuracy: 0.001
        )
        XCTAssertEqual(Language.finnish.locale.identifier, "fi")
        XCTAssertEqual(Language.swedish.locale.identifier, "sv")
        XCTAssertFalse(sut.string(for: pressure, allowSettings: false).isEmpty)
        XCTAssertEqual(
            sut.double(for: humidity, temperature: temperature, isDecimal: false) ?? .nan,
            45,
            accuracy: 0.001
        )
        XCTAssertFalse(
            sut.string(
                for: humidity,
                temperature: temperature,
                allowSettings: false,
                unit: .percent
            ).isEmpty
        )
        XCTAssertEqual(
            sut.string(for: nil as Humidity?, temperature: temperature, allowSettings: true),
            "-"
        )
        XCTAssertEqual(sut.temperatureOffsetCorrection(for: 2.5), 2.5)

        let metricSettings = makeSettings()
        metricSettings.language = .finnish
        let metricSut = RuuviServiceMeasurementImpl(
            settings: metricSettings,
            emptyValueString: "-",
            percentString: "%"
        )
        XCTAssertFalse(metricSut.string(for: temperature, allowSettings: true).isEmpty)

        let pascalSettings = makeSettings()
        pascalSettings.pressureUnit = .newtonsPerMetersSquared
        let pascalSut = RuuviServiceMeasurementImpl(
            settings: pascalSettings,
            emptyValueString: "-",
            percentString: "%"
        )
        XCTAssertEqual(pascalSut.stringWithoutSign(pressure: 101_325.4), "101325")

        let absoluteSettings = makeSettings()
        absoluteSettings.humidityUnit = .gm3
        let absoluteSut = RuuviServiceMeasurementImpl(
            settings: absoluteSettings,
            emptyValueString: "-",
            percentString: "%"
        )
        XCTAssertNotNil(absoluteSut.double(for: humidity, temperature: temperature, isDecimal: true))

        let dewSettings = makeSettings()
        dewSettings.humidityUnit = .dew
        let dewSut = RuuviServiceMeasurementImpl(
            settings: dewSettings,
            emptyValueString: "-",
            percentString: "%"
        )
        XCTAssertNotNil(dewSut.double(for: humidity, temperature: temperature, isDecimal: true))
    }

    func testMeasurementDewPointFormattingReturnsEmptyForOutOfRangeTemperature() {
        let settings = makeSettings()
        settings.humidityUnit = .dew
        let sut = RuuviServiceMeasurementImpl(
            settings: settings,
            emptyValueString: "-",
            percentString: "%"
        )
        let temperature = Temperature(value: -80, unit: .celsius)
        let humidity = Humidity(value: 0.45, unit: .relative(temperature: temperature))

        XCTAssertNil(sut.double(for: humidity, temperature: temperature, isDecimal: true))
        XCTAssertEqual(
            sut.string(
                for: humidity,
                temperature: temperature,
                allowSettings: true,
                unit: .dew
            ),
            "-"
        )
        XCTAssertEqual(sut.stringWithoutSign(for: humidity, temperature: temperature), "-")
    }

    func testExportHeaderHelpersCoverEveryMeasurementVariant() {
        let shortNameCases: [(MeasurementDisplayVariant, String)] = [
            (.init(type: .temperature), RuuviLocalization.temperature),
            (.init(type: .humidity), RuuviLocalization.relHumidity),
            (.init(type: .humidity, humidityUnit: .percent), RuuviLocalization.relHumidity),
            (.init(type: .humidity, humidityUnit: .gm3), RuuviLocalization.absHumidity),
            (.init(type: .humidity, humidityUnit: .dew), RuuviLocalization.dewpoint),
            (.init(type: .pressure), RuuviLocalization.pressure),
            (.init(type: .movementCounter), RuuviLocalization.movements),
            (.init(type: .voltage), RuuviLocalization.battery),
            (.init(type: .rssi), RuuviLocalization.signalStrength),
            (.init(type: .accelerationX), RuuviLocalization.accX),
            (.init(type: .accelerationY), RuuviLocalization.accY),
            (.init(type: .accelerationZ), RuuviLocalization.accZ),
            (.init(type: .aqi), RuuviLocalization.airQuality),
            (.init(type: .co2), RuuviLocalization.co2),
            (.init(type: .pm10), RuuviLocalization.pm10),
            (.init(type: .pm25), RuuviLocalization.pm25),
            (.init(type: .pm40), RuuviLocalization.pm40),
            (.init(type: .pm100), RuuviLocalization.pm100),
            (.init(type: .nox), RuuviLocalization.nox),
            (.init(type: .voc), RuuviLocalization.voc),
            (.init(type: .soundInstant), RuuviLocalization.soundInstant),
            (.init(type: .soundAverage), RuuviLocalization.soundAvg),
            (.init(type: .soundPeak), RuuviLocalization.soundPeak),
            (.init(type: .luminosity), RuuviLocalization.light),
            (.init(type: .measurementSequenceNumber), RuuviLocalization.measSeqNumber),
            (.init(type: .txPower), ""),
        ]

        for (variant, expected) in shortNameCases {
            XCTAssertEqual(RuuviServiceExportImpl.shortName(for: variant), expected)
        }

        XCTAssertEqual(
            RuuviServiceExportImpl.shortNameWithUnit(for: .init(type: .temperature)),
            RuuviLocalization.temperatureWithUnit(UnitTemperature.celsius.symbol)
        )
        XCTAssertEqual(
            RuuviServiceExportImpl.shortNameWithUnit(
                for: .init(type: .temperature, temperatureUnit: .fahrenheit)
            ),
            RuuviLocalization.temperatureWithUnit(UnitTemperature.fahrenheit.symbol)
        )
        XCTAssertTrue(
            RuuviServiceExportImpl.shortNameWithUnit(
                for: .init(type: .humidity)
            ).contains(RuuviLocalization.humidityRelativeUnit)
        )
        XCTAssertTrue(
            RuuviServiceExportImpl.shortNameWithUnit(
                for: .init(type: .humidity, humidityUnit: .gm3)
            ).contains(RuuviLocalization.absHumidity)
        )
        XCTAssertEqual(
            RuuviServiceExportImpl.shortNameWithUnit(
                for: .init(type: .humidity, temperatureUnit: .fahrenheit, humidityUnit: .dew)
            ),
            RuuviLocalization.dewpoint + " (\(UnitTemperature.fahrenheit.symbol))"
        )
        XCTAssertEqual(
            RuuviServiceExportImpl.shortNameWithUnit(
                for: .init(type: .pressure, pressureUnit: .newtonsPerMetersSquared)
            ),
            RuuviLocalization.pressureWithUnit(UnitPressure.newtonsPerMetersSquared.ruuviSymbol)
        )
        XCTAssertEqual(
            RuuviServiceExportImpl.shortNameWithUnit(for: .init(type: .pressure)),
            RuuviLocalization.pressureWithUnit(UnitPressure.hectopascals.ruuviSymbol)
        )

        let unitHeaderTypes: [MeasurementType] = [
            .movementCounter,
            .voltage,
            .accelerationX,
            .accelerationY,
            .accelerationZ,
            .aqi,
            .co2,
            .pm10,
            .pm25,
            .pm40,
            .pm100,
            .voc,
            .nox,
            .soundInstant,
            .soundAverage,
            .soundPeak,
            .luminosity,
            .rssi,
            .measurementSequenceNumber,
        ]

        for type in unitHeaderTypes {
            XCTAssertFalse(
                RuuviServiceExportImpl.shortNameWithUnit(for: .init(type: type)).isEmpty
            )
        }
        XCTAssertEqual(RuuviServiceExportImpl.shortNameWithUnit(for: .init(type: .txPower)), "")
    }

    func testExportCsvUsesEmptyValueForOutOfRangeDewPointColumns() async throws {
        let settings = makeSettings()
        let sensor = makeSensor(name: "Cold/Sensor")
        let storage = StorageSpy()
        storage.readOneResult = sensor.any
        storage.readAllAfterResult = [
            makeRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                date: Date(timeIntervalSince1970: 1_700_003_000),
                temperature: -80,
                humidity: 0.45
            ),
        ]
        let sut = RuuviServiceExportImpl(
            ruuviStorage: storage,
            measurementService: RuuviServiceMeasurementImpl(
                settings: settings,
                emptyValueString: "-",
                percentString: "%"
            ),
            emptyValueString: "-",
            ruuviLocalSettings: settings
        )

        let url = try await sut.csvLog(for: sensor.id, version: 5, settings: nil)
        let text = try String(contentsOf: url)
        let rows = text.split(separator: "\n")
        let columns = rows[1].split(separator: ",")

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(columns[6], "-")
        XCTAssertEqual(columns[7], "-")
        XCTAssertEqual(columns[8], "-")
    }

    func testExportCsvSurfacesWriteToDiskErrors() async throws {
        let settings = makeSettings()
        let sensor = makeSensor(name: String(repeating: "x", count: 300))
        let storage = StorageSpy()
        storage.readOneResult = sensor.any
        storage.readAllAfterResult = [
            makeRecord(
                luid: sensor.luid?.value,
                macId: sensor.macId?.value,
                date: Date(timeIntervalSince1970: 1_700_004_000),
                temperature: 20
            ),
        ]
        let sut = RuuviServiceExportImpl(
            ruuviStorage: storage,
            measurementService: RuuviServiceMeasurementImpl(
                settings: settings,
                emptyValueString: "-",
                percentString: "%"
            ),
            emptyValueString: "-",
            ruuviLocalSettings: settings
        )

        do {
            _ = try await sut.csvLog(for: sensor.id, version: 5, settings: nil)
            XCTFail("Expected write failure for an invalid file name")
        } catch let error as RuuviServiceError {
            guard case .writeToDisk = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSensorPropertiesFailureFallbackAndEmptyDisplayOrderBranches() async throws {
        let failingImages = LocalImagesSpy()
        failingImages.setNextDefaultBackgroundShouldFail = true
        let failingBackgroundSut = RuuviServiceSensorPropertiesImpl(
            pool: PoolSpy(),
            cloud: CloudSpy(),
            coreImage: CoreImageSpy(),
            localImages: failingImages
        )

        do {
            _ = try await failingBackgroundSut.setNextDefaultBackground(
                luid: "luid-fail".luid,
                macId: nil
            )
            XCTFail("Expected background generation failure")
        } catch let error as RuuviServiceError {
            guard case .failedToFindOrGenerateBackgroundImage = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let cloud = CloudSpy()
        cloud.uploadError = RuuviCloudError.api(.connection)
        let uploadImages = LocalImagesSpy()
        let uploadFailureSut = RuuviServiceSensorPropertiesImpl(
            pool: PoolSpy(),
            cloud: cloud,
            coreImage: CoreImageSpy(),
            localImages: uploadImages
        )
        let cloudSensor = makeSensor(isCloud: true)

        do {
            _ = try await uploadFailureSut.set(
                image: makeImage(color: .blue),
                for: cloudSensor,
                progress: nil,
                maxSize: CGSize(width: 8, height: 8),
                compressionQuality: 0.7
            )
            XCTFail("Expected upload failure")
        } catch let error as RuuviServiceError {
            guard case .ruuviCloud = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertNil(uploadImages.backgroundUploadProgress(for: cloudSensor.macId!))

        let localLuidImages = LocalImagesSpy()
        let localLuidSut = RuuviServiceSensorPropertiesImpl(
            pool: PoolSpy(),
            cloud: CloudSpy(),
            coreImage: CoreImageSpy(),
            localImages: localLuidImages
        )
        let localLuidSensor = makeSensor(luid: "local-luid", macId: nil, isCloud: false)
        _ = try await localLuidSut.set(
            image: makeImage(color: .orange),
            for: localLuidSensor,
            progress: nil,
            maxSize: CGSize(width: 10, height: 10),
            compressionQuality: 0.6
        )
        XCTAssertEqual(localLuidImages.setCustomBackgroundCalls.first?.identifier, "local-luid")

        let fallbackImages = LocalImagesSpy()
        let generatedMacImage = makeImage(color: .cyan)
        fallbackImages.generatedBackgrounds["AA:BB:CC:11:22:33"] = generatedMacImage
        let fallbackSut = RuuviServiceSensorPropertiesImpl(
            pool: PoolSpy(),
            cloud: CloudSpy(),
            coreImage: CoreImageSpy(),
            localImages: fallbackImages
        )
        let fallbackImage = try await fallbackSut.getImage(
            for: makeSensor(luid: nil, macId: "AA:BB:CC:11:22:33")
        )
        XCTAssertEqual(fallbackImage.pngData(), generatedMacImage.pngData())

        do {
            _ = try await fallbackSut.getImage(for: makeSensor(luid: nil, macId: nil))
            XCTFail("Expected missing identifier error")
        } catch let error as RuuviServiceError {
            guard case .bothLuidAndMacAreNil = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let displayCloud = CloudSpy()
        let displayPool = PoolSpy()
        displayPool.readSensorSettingsResult = SensorSettingsStruct(
            luid: "display-luid".luid,
            macId: "AA:BB:CC:11:22:33".mac,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil
        )
        let displaySut = RuuviServiceSensorPropertiesImpl(
            pool: displayPool,
            cloud: displayCloud,
            coreImage: CoreImageSpy(),
            localImages: LocalImagesSpy()
        )
        _ = try await displaySut.updateDisplaySettings(
            for: makeSensor(luid: "display-luid", isCloud: true),
            displayOrder: [],
            defaultDisplayOrder: true
        )
        XCTAssertNotNil(displayPool.displaySettingsCalls.first?.displayOrderLastUpdated)
        XCTAssertNotNil(displayPool.displaySettingsCalls.first?.defaultDisplayOrderLastUpdated)
        XCTAssertEqual(
            displayCloud.updateSensorSettingsCalls.first?.types,
            [RuuviCloudApiSetting.sensorDefaultDisplayOrder.rawValue]
        )

        _ = try await displaySut.updateDescription(
            for: makeSensor(luid: "display-luid", isCloud: true),
            description: nil
        )
        XCTAssertEqual(displayCloud.updateSensorSettingsCalls.last?.values, [""])
    }

    func testSensorPropertiesCoversImageFailuresAndDefaultDisplayOrderChange() async throws {
        let images = LocalImagesSpy()
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: PoolSpy(),
            cloud: CloudSpy(),
            coreImage: CoreImageSpy(),
            localImages: images
        )

        do {
            _ = try await sut.getImage(for: makeSensor(luid: nil, macId: "AA:BB:CC:11:22:44"))
            XCTFail("Expected missing generated MAC image to fail")
        } catch let error as RuuviServiceError {
            guard case .failedToFindOrGenerateBackgroundImage = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await sut.getImage(for: makeSensor(luid: "missing-luid", macId: nil))
            XCTFail("Expected missing generated LUID image to fail")
        } catch let error as RuuviServiceError {
            guard case .failedToFindOrGenerateBackgroundImage = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let invalidJpegCoreImage = CoreImageSpy()
        invalidJpegCoreImage.croppedImage = UIImage()
        let invalidJpegSut = RuuviServiceSensorPropertiesImpl(
            pool: PoolSpy(),
            cloud: CloudSpy(),
            coreImage: invalidJpegCoreImage,
            localImages: LocalImagesSpy()
        )
        do {
            _ = try await invalidJpegSut.set(
                image: UIImage(),
                for: makeSensor(macId: "AA:BB:CC:11:22:45"),
                progress: nil,
                maxSize: CGSize(width: 8, height: 8),
                compressionQuality: 0.7
            )
            XCTFail("Expected missing JPEG representation error")
        } catch let error as RuuviServiceError {
            guard case .failedToGetJpegRepresentation = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let generatedLuidImage = makeImage(color: .purple)
        images.generatedBackgrounds["generated-luid"] = generatedLuidImage
        let image = try await sut.getImage(for: makeSensor(luid: "generated-luid", macId: nil))
        XCTAssertEqual(image.pngData(), generatedLuidImage.pngData())

        let pool = PoolSpy()
        pool.readSensorSettingsResult = SensorSettingsStruct(
            luid: "display-luid".luid,
            macId: "AA:BB:CC:11:22:33".mac,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            displayOrder: ["temperature"],
            defaultDisplayOrder: true,
            displayOrderLastUpdated: Date(timeIntervalSince1970: 1),
            defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 1)
        )
        let displaySut = RuuviServiceSensorPropertiesImpl(
            pool: pool,
            cloud: CloudSpy(),
            coreImage: CoreImageSpy(),
            localImages: LocalImagesSpy()
        )
        _ = try await displaySut.updateDisplaySettings(
            for: makeSensor(luid: "display-luid", isCloud: false),
            displayOrder: ["temperature"],
            defaultDisplayOrder: false
        )
        XCTAssertNil(pool.displaySettingsCalls.first?.displayOrderLastUpdated)
        XCTAssertNotNil(pool.displaySettingsCalls.first?.defaultDisplayOrderLastUpdated)
    }

    func testSensorPropertiesSetImageFailsDeterministicallyWithoutIdentifiers() async {
        let sut = RuuviServiceSensorPropertiesImpl(
            pool: PoolSpy(),
            cloud: CloudSpy(),
            coreImage: CoreImageSpy(),
            localImages: LocalImagesSpy()
        )

        do {
            _ = try await sut.set(
                image: makeImage(color: .gray),
                for: makeSensor(luid: nil, macId: nil, isCloud: false),
                progress: nil,
                maxSize: CGSize(width: 8, height: 8),
                compressionQuality: 0.7
            )
            XCTFail("Expected missing identifiers error")
        } catch let error as RuuviServiceError {
            guard case .bothLuidAndMacAreNil = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAlertAbsoluteHumidityMutatorsPushCloudUpdatesForCloudSensor() async {
        let cloud = CloudSpy()
        let sensor = makeSensor(isCloud: true)
        let sut = RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: RuuviLocalIDsUserDefaults(),
            ruuviLocalSettings: makeSettings()
        )
        let initialLow = Humidity(value: 2.5, unit: .absolute)
        let initialHigh = Humidity(value: 6.5, unit: .absolute)
        let updatedLow = Humidity(value: 3.5, unit: .absolute)
        let updatedHigh = Humidity(value: 7.5, unit: .absolute)

        sut.register(type: .humidity(lower: initialLow, upper: initialHigh), ruuviTag: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        cloud.setAlertCalls.removeAll()

        sut.setLower(humidity: updatedLow, for: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        assertAlertCall(
            cloud.setAlertCalls[0],
            type: .humidityAbsolute,
            settingType: .lowerBound,
            isEnabled: true,
            min: updatedLow.value,
            max: initialHigh.value,
            counter: nil,
            delay: nil
        )

        cloud.setAlertCalls.removeAll()
        sut.setUpper(humidity: updatedHigh, for: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        assertAlertCall(
            cloud.setAlertCalls[0],
            type: .humidityAbsolute,
            settingType: .upperBound,
            isEnabled: true,
            min: updatedLow.value,
            max: updatedHigh.value,
            counter: nil,
            delay: nil
        )

        cloud.setAlertCalls.removeAll()
        sut.setHumidity(description: "absolute cloud", for: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        assertAlertCall(
            cloud.setAlertCalls[0],
            type: .humidityAbsolute,
            settingType: .description,
            isEnabled: true,
            min: updatedLow.value,
            max: updatedHigh.value,
            counter: nil,
            delay: nil,
            description: "absolute cloud"
        )
    }

    func testCloudSyncSettingsBackfillsMissingProfileLanguageToCloud() async throws {
        let cloud = CloudSpy()
        cloud.getCloudSettingsResult = makeCloudSettings(profileLanguageCode: nil)
        let settings = makeSettings()
        settings.language = .finnish
        let syncState = RuuviLocalSyncStateUserDefaults()
        let localIDs = RuuviLocalIDsUserDefaults()
        let appSettings = RuuviServiceAppSettingsImpl(cloud: cloud, localSettings: settings)
        let sut = RuuviServiceCloudSyncImpl(
            ruuviStorage: StorageSpy(),
            ruuviCloud: cloud,
            ruuviPool: PoolSpy(),
            ruuviLocalSettings: settings,
            ruuviLocalSyncState: syncState,
            ruuviLocalImages: LocalImagesSpy(),
            ruuviRepository: RepositorySpy(),
            ruuviLocalIDs: localIDs,
            ruuviAlertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: localIDs,
                ruuviLocalSettings: settings
            ),
            ruuviAppSettingsService: appSettings
        )

        let result = try await sut.syncSettings()

        XCTAssertNil(result.profileLanguageCode)
        XCTAssertEqual(settings.cloudProfileLanguageCode, "fi")
        await waitUntil {
            cloud.setProfileLanguageCodeValues == ["fi"]
        }
    }

    func testCloudSyncSettingsCoversRemainingRemoteSettingBranches() async throws {
        let cloud = CloudSpy()
        cloud.getCloudSettingsResult = makeCloudSettings(
            chartShowAllPoints: true,
            dashboardType: .image,
            dashboardTapActionType: .card,
            profileLanguageCode: "sv"
        )
        let settings = makeSettings()
        settings.chartDownsamplingOn = true
        settings.dashboardType = .simple
        settings.dashboardTapActionType = .chart
        settings.cloudProfileLanguageCode = "fi"
        let sut = makeCoverageCloudSyncService(cloud: cloud, settings: settings)

        let result = try await sut.syncSettings()

        XCTAssertEqual(result.profileLanguageCode, "sv")
        XCTAssertFalse(settings.chartDownsamplingOn)
        XCTAssertEqual(settings.dashboardType, .image)
        XCTAssertEqual(settings.dashboardTapActionType, .card)
        XCTAssertEqual(settings.cloudProfileLanguageCode, "sv")
    }

    func testCloudSyncAllIgnoresPendingRequestFailureAndSetsGlobalSyncDate() async throws {
        let cloud = CloudSpy()
        cloud.getCloudSettingsResult = makeCloudSettings()
        cloud.loadSensorsDenseResult = []
        let storage = StorageSpy()
        storage.readQueuedRequestsError = RuuviCloudError.api(.connection)
        storage.readAllResult = []
        let syncState = RuuviLocalSyncStateUserDefaults()
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: makeSettings(),
            syncState: syncState
        )

        let result = try await sut.syncAll()

        XCTAssertTrue(result.isEmpty)
        XCTAssertNotNil(syncState.getSyncDate())
    }

    func testCloudSyncAllRecordsSuccessResetsSyncingFlag() async throws {
        let cloud = CloudSpy()
        cloud.getCloudSettingsResult = makeCloudSettings()
        cloud.loadSensorsDenseResult = []
        let settings = makeSettings()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let storage = StorageSpy()
        storage.readAllResult = []
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: settings,
            syncState: syncState
        )

        let result = try await sut.syncAllRecords()

        XCTAssertTrue(result)
        XCTAssertFalse(settings.isSyncing)
        await waitUntil {
            syncState.syncStatus == .none
        }
    }

    func testCloudSyncRefreshLatestRecordSavesSubscriptionAndNoHistorySyncDate() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let settings = makeSettings()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:33",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: Date(timeIntervalSince1970: 100)
        ).with(maxHistoryDays: 0)
        let recordDate = Date(timeIntervalSince1970: 1_700_200_000)
        let cloudSensor = CloudSensorStruct(
            id: sensor.id,
            serviceUUID: nil,
            name: "Cloud Sensor",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "pro",
            picture: nil,
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            isCloudSensor: true,
            canShare: true,
            sharedTo: [],
            maxHistoryDays: 0,
            lastUpdated: sensor.lastUpdated
        )
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: cloudSensor,
                record: makeRecord(macId: sensor.id, date: recordDate),
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: CloudSensorSubscriptionCoverageStub(
                    subscriptionName: "Pro",
                    maxHistoryDays: 0
                )
            ),
        ]
        storage.readAllResult = [sensor.any]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: settings,
            syncState: syncState
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertEqual(pool.savedSubscriptions.count, 1)
        XCTAssertEqual(pool.savedSubscriptions.first?.macId, sensor.id)
        XCTAssertEqual(syncState.getSyncDate(for: sensor.macId), recordDate)
        XCTAssertEqual(pool.createdLastRecord?.date, recordDate)
    }

    func testCloudSyncSensorHistoryReturnsEmptyWhenHistoryIsDisabled() async throws {
        let sut = makeCoverageCloudSyncService(settings: makeSettings())

        let result = try await sut.sync(sensor: makeSensor(isCloud: true))

        XCTAssertTrue(result.isEmpty)
    }

    func testCloudSyncSensorHistoryMarksErrorWhenRecordDownloadFails() async {
        let cloud = CloudSpy()
        cloud.loadRecordsError = NSError(domain: "RuuviServiceTests", code: 41)
        let syncState = RuuviLocalSyncStateUserDefaults()
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:80",
            isCloud: true
        ).with(maxHistoryDays: 14)
        let sensorMac = sensor.macId?.value
        let statusChanged = expectation(description: "history sync marked as error")
        let observer = NotificationCenter.default.addObserver(
            forName: .NetworkSyncHistoryDidChangeStatus,
            object: nil,
            queue: .main
        ) { notification in
            let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus
            let mac = notification.userInfo?[NetworkSyncStatusKey.mac] as? MACIdentifier
            if status == .onError, mac?.value == sensorMac {
                statusChanged.fulfill()
            }
        }
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        let sut = makeCoverageCloudSyncService(
            cloud: cloud,
            settings: makeSettings(),
            syncState: syncState
        )

        do {
            _ = try await sut.sync(sensor: sensor)
            XCTFail("Expected history sync to fail")
        } catch let error as RuuviServiceError {
            guard case .networking = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [statusChanged], timeout: 1)
    }

    func testCloudSyncSensorHistoryHandlesForcedFullSyncWithNoRecords() async throws {
        let cloud = CloudSpy()
        cloud.loadRecordsResult = []
        let repository = RepositorySpy()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:92",
            isCloud: true
        ).with(maxHistoryDays: 14)
        syncState.setDownloadFullHistory(for: sensor.macId, downloadFull: true)
        let sut = makeCoverageCloudSyncService(
            cloud: cloud,
            settings: makeSettings(),
            syncState: syncState,
            repository: repository
        )

        let result = try await sut.sync(sensor: sensor)

        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(repository.createdRecords.isEmpty)
        XCTAssertFalse(syncState.downloadFullHistory(for: sensor.macId) == true)
        XCTAssertNil(syncState.getSyncDate(for: sensor.macId))
    }

    func testCloudSyncRecordsOperationCoversEmptyAndCloudErrorBranches() async {
        let emptyCloud = CloudSpy()
        emptyCloud.loadRecordsResult = []
        let emptyOperation = RuuviServiceCloudSyncRecordsOperation(
            sensor: makeSensor(),
            since: Date(),
            ruuviCloud: emptyCloud,
            ruuviRepository: RepositorySpy(),
            syncState: RuuviLocalSyncStateUserDefaults(),
            ruuviLocalIDs: RuuviLocalIDsUserDefaults()
        )

        emptyOperation.start()
        await waitUntil {
            emptyOperation.isFinished
        }
        XCTAssertNil(emptyOperation.error)
        XCTAssertTrue(emptyOperation.records.isEmpty)

        let cloudErrorCloud = CloudSpy()
        cloudErrorCloud.loadRecordsError = RuuviCloudError.api(.connection)
        let cloudErrorOperation = RuuviServiceCloudSyncRecordsOperation(
            sensor: makeSensor(),
            since: Date(),
            ruuviCloud: cloudErrorCloud,
            ruuviRepository: RepositorySpy(),
            syncState: RuuviLocalSyncStateUserDefaults(),
            ruuviLocalIDs: RuuviLocalIDsUserDefaults()
        )

        cloudErrorOperation.start()
        await waitUntil {
            cloudErrorOperation.isFinished
        }
        guard case .ruuviCloud? = cloudErrorOperation.error else {
            return XCTFail("Expected cloud error, got \(String(describing: cloudErrorOperation.error))")
        }

        let unknownErrorCloud = CloudSpy()
        unknownErrorCloud.loadRecordsError = NSError(domain: "coverage", code: 1)
        let unknownErrorOperation = RuuviServiceCloudSyncRecordsOperation(
            sensor: makeSensor(),
            since: Date(),
            ruuviCloud: unknownErrorCloud,
            ruuviRepository: RepositorySpy(),
            syncState: RuuviLocalSyncStateUserDefaults(),
            ruuviLocalIDs: RuuviLocalIDsUserDefaults()
        )

        unknownErrorOperation.start()
        await waitUntil {
            unknownErrorOperation.isFinished
        }
        guard case .networking? = unknownErrorOperation.error else {
            return XCTFail("Expected networking error, got \(String(describing: unknownErrorOperation.error))")
        }
    }

    func testAlertPersistenceMuteAndTriggerMappingsCoverEveryAlertType() {
        let sut = AlertPersistenceUserDefaults()
        let mutedTill = Date(timeIntervalSince1970: 1_775_000_000)
        let triggeredAt = "2026-04-20T00:00:00Z"

        for (index, type) in AlertType.allCases.enumerated() {
            let uuid = "alert-persistence-\(index)"

            sut.mute(type: type, for: uuid, till: mutedTill)
            XCTAssertEqual(sut.mutedTill(type: type, for: uuid), mutedTill)

            sut.trigger(
                type: type,
                trigerred: true,
                trigerredAt: triggeredAt,
                for: uuid
            )
            XCTAssertEqual(sut.triggered(for: uuid, of: type), true)
            XCTAssertEqual(sut.triggeredAt(for: uuid, of: type), triggeredAt)

            sut.unmute(type: type, for: uuid)
            XCTAssertNil(sut.mutedTill(type: type, for: uuid))
        }

        let humidityUUID = "alert-persistence-humidity-nil"
        XCTAssertNil(sut.lowerHumidity(for: humidityUUID))
        XCTAssertNil(sut.upperHumidity(for: humidityUUID))
        sut.setLower(humidity: Humidity(value: 1, unit: .absolute), for: humidityUUID)
        sut.setUpper(humidity: Humidity(value: 5, unit: .absolute), for: humidityUUID)
        XCTAssertEqual(sut.lowerHumidity(for: humidityUUID)?.value, 1)
        XCTAssertEqual(sut.upperHumidity(for: humidityUUID)?.value, 5)
        sut.setLower(humidity: nil, for: humidityUUID)
        sut.setUpper(humidity: nil, for: humidityUUID)
        XCTAssertNil(sut.lowerHumidity(for: humidityUUID))
        XCTAssertNil(sut.upperHumidity(for: humidityUUID))
    }

    func testGATTServiceDefaultConvenienceUsesNilProgressAndTimeouts() async throws {
        let stub = GATTServiceStub()
        let settings = SensorSettingsStruct(
            luid: "luid-1".luid,
            macId: "AA:BB:CC:11:22:33".mac,
            temperatureOffset: 1,
            humidityOffset: 2,
            pressureOffset: 3
        )
        let sut: GATTService = stub

        let result = try await sut.syncLogs(
            uuid: "luid-1",
            mac: "AA:BB:CC:11:22:33",
            firmware: 5,
            from: Date(timeIntervalSince1970: 100),
            settings: settings
        )

        XCTAssertTrue(result)
        XCTAssertEqual(stub.syncLogsCalls.count, 1)
        XCTAssertEqual(stub.syncLogsCalls.first?.uuid, "luid-1")
        XCTAssertEqual(stub.syncLogsCalls.first?.progressWasProvided, false)
        XCTAssertNil(stub.syncLogsCalls.first?.connectionTimeout)
        XCTAssertNil(stub.syncLogsCalls.first?.serviceTimeout)
    }

    func testGATTServiceDefaultQueuedAndStopImplementationsReturnFalse() async throws {
        let sut: GATTService = DefaultGATTServiceStub()
        let stopped = try await sut.stopGattSync(for: "luid-1")

        XCTAssertFalse(sut.isSyncingLogsQueued(with: "luid-1"))
        XCTAssertFalse(stopped)
    }

    func testOffsetCalibrationConvenienceOverloadPassesNilLastOriginalRecord() async throws {
        let stub = OffsetCalibrationStub()
        let sut: RuuviServiceOffsetCalibration = stub
        let sensor = makeSensor()

        let settings = try await sut.set(
            offset: 1.5,
            of: .temperature,
            for: sensor
        )

        XCTAssertEqual(stub.calls.count, 1)
        XCTAssertEqual(stub.calls.first?.sensorID, sensor.id)
        XCTAssertEqual(stub.calls.first?.type, .temperature)
        XCTAssertEqual(try XCTUnwrap(stub.calls.first?.offset), 1.5, accuracy: 0.0001)
        XCTAssertNil(stub.calls.first?.lastOriginalRecord)
        XCTAssertEqual(settings.luid?.value, sensor.luid?.value)
        XCTAssertEqual(settings.macId?.value, sensor.macId?.value)
    }

    func testCloudSyncRefreshLatestRecordUpdatesSensorLatestAndHistory() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let settings = makeSettings()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:33",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: Date(timeIntervalSince1970: 100)
        )
        let cloudSensor = CloudSensorStruct(
            id: sensor.id,
            serviceUUID: nil,
            name: "Cloud Sensor",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "pro",
            picture: nil,
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            isCloudSensor: true,
            canShare: true,
            sharedTo: [],
            maxHistoryDays: nil,
            lastUpdated: Date(timeIntervalSince1970: 200)
        )
        let previous = makeRecord(
            macId: sensor.id,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            measurementSequenceNumber: 1
        )
        let latest = makeRecord(
            macId: sensor.id,
            date: Date(timeIntervalSince1970: 1_700_000_300),
            temperature: 22.4,
            measurementSequenceNumber: 2
        )
        storage.readAllResult = [sensor.any]
        storage.readLatestResults[sensor.id] = previous
        storage.readLastResults[sensor.id] = previous
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: cloudSensor,
                record: latest,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            )
        ]
        let sut = RuuviServiceCloudSyncImpl(
            ruuviStorage: storage,
            ruuviCloud: cloud,
            ruuviPool: pool,
            ruuviLocalSettings: settings,
            ruuviLocalSyncState: syncState,
            ruuviLocalImages: LocalImagesSpy(),
            ruuviRepository: RepositorySpy(),
            ruuviLocalIDs: RuuviLocalIDsUserDefaults(),
            ruuviAlertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: settings
            ),
            ruuviAppSettingsService: RuuviServiceAppSettingsImpl(cloud: cloud, localSettings: settings)
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertEqual(pool.updatedSensors.first?.name, "Cloud Sensor")
        XCTAssertEqual(pool.updatedLastRecord?.measurementSequenceNumber, 2)
        XCTAssertEqual(pool.createdRecord?.measurementSequenceNumber, 2)
        XCTAssertNotNil(syncState.getSyncDate())
        XCTAssertEqual(syncState.getSyncStatusLatestRecord(for: sensor.macId!), .complete)
    }

    func testCloudSyncImageDefaultLoaderCachesDownloadedPicture() async throws {
        let localImages = LocalImagesSpy()
        let image = makeImage(color: .brown)
        let imageData = try XCTUnwrap(image.jpegData(compressionQuality: 1.0))
        let imageURL = try XCTUnwrap(URL(string: "https://cloud-sync-image.test/background.jpg"))
        CloudSyncImageURLProtocol.reset(with: imageData)
        _ = URLProtocol.registerClass(CloudSyncImageURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(CloudSyncImageURLProtocol.self)
            CloudSyncImageURLProtocol.reset(with: nil)
        }
        let sut = makeCoverageCloudSyncService(
            cloud: CloudSpy(),
            settings: makeSettings(),
            localImages: localImages
        )
        let sensor = makeCloudSensor(
            id: "AA:BB:CC:11:22:73",
            picture: imageURL
        )

        let url = try await sut.syncImage(sensor: sensor)

        XCTAssertEqual(url, localImages.setCustomBackgroundURL)
        XCTAssertEqual(localImages.setCustomBackgroundCalls.first?.identifier, sensor.id)
        XCTAssertEqual(localImages.setPictureIsCachedIDs, [sensor.id])
        XCTAssertEqual(CloudSyncImageURLProtocol.requestedURLs, [imageURL])
    }

    func testCloudSyncRefreshLatestRecordSkipsLatestAndHistoryWhenCloudRecordIsMissing() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:81",
            name: "Cloud Sensor",
            isCloud: true,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com"
        )
        storage.readAllResult = [sensor.any]
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: makeCloudSensor(id: sensor.id, name: sensor.name),
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings(),
            syncState: syncState
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertNil(pool.createdLastRecord)
        XCTAssertNil(pool.updatedLastRecord)
        XCTAssertNil(pool.createdRecord)
        XCTAssertEqual(syncState.getSyncStatusLatestRecord(for: sensor.macId!), .complete)
    }

    func testCloudSyncRefreshLatestRecordQueuesSensorVersionUpdateWhenCloudRecordVersionChanges() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let timestamp = Date(timeIntervalSince1970: 100)
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:74",
            version: 5,
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: timestamp
        )
        storage.readAllResult = [sensor.any]
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: sensor.name,
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: "pro",
                    picture: nil,
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: timestamp
                ),
                record: makeRecord(
                    macId: sensor.id,
                    version: 6,
                    date: Date(timeIntervalSince1970: 1_700_000_400),
                    measurementSequenceNumber: 6
                ),
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            )
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings(),
            syncState: syncState
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        await waitUntil {
            pool.updatedSensors.contains { $0.version == 6 }
        }
        XCTAssertTrue(pool.updatedSensors.contains { $0.version == 6 })
    }

    func testCloudSyncRefreshLatestRecordCreatesHistoryWhenLatestHistoryReadFails() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let timestamp = Date(timeIntervalSince1970: 100)
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:82",
            name: "History Sensor",
            isCloud: true,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: timestamp
        )
        let cloudRecord = makeRecord(
            macId: sensor.id,
            date: Date(timeIntervalSince1970: 1_700_000_600),
            measurementSequenceNumber: 8
        )
        storage.readAllResult = [sensor.any]
        storage.readLatestResults[sensor.id] = makeRecord(
            macId: sensor.id,
            date: Date(timeIntervalSince1970: 1_700_000_300),
            measurementSequenceNumber: 7
        )
        storage.readLastError = NSError(domain: "RuuviServiceTests", code: 42)
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: sensor.name,
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: nil,
                    picture: nil,
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: timestamp
                ),
                record: cloudRecord,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings(),
            syncState: syncState
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertEqual(pool.updatedLastRecord?.measurementSequenceNumber, 8)
        XCTAssertEqual(pool.createdRecord?.measurementSequenceNumber, 8)
        XCTAssertEqual(pool.createdRecord?.macId?.value, sensor.id)
    }

    func testCloudSyncRefreshLatestRecordMarksLatestStatusErrorWhenLatestReadFails() async {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let timestamp = Date(timeIntervalSince1970: 100)
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:84",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: timestamp
        )
        storage.readAllResult = [sensor.any]
        storage.readLatestError = NSError(domain: "RuuviServiceTests", code: 84)
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: sensor.name,
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: nil,
                    picture: nil,
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: timestamp
                ),
                record: makeRecord(
                    macId: sensor.id,
                    date: Date(timeIntervalSince1970: 1_700_000_700),
                    measurementSequenceNumber: 9
                ),
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings(),
            syncState: syncState
        )

        do {
            _ = try await sut.refreshLatestRecord()
            XCTFail("Expected latest read failure")
        } catch let error as RuuviServiceError {
            guard case .networking = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(pool.updatedLastRecord)
        XCTAssertNil(pool.createdLastRecord)
        XCTAssertEqual(syncState.getSyncStatusLatestRecord(for: sensor.macId!), .onError)
    }

    func testCloudSyncRefreshLatestRecordSkipsStaleCloudMeasurementWhenCloudModeIsOff() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let settings = makeSettings()
        settings.cloudModeEnabled = false
        let timestamp = Date(timeIntervalSince1970: 100)
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:85",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: timestamp
        )
        let localRecord = makeRecord(
            macId: sensor.id,
            date: Date(timeIntervalSince1970: 1_700_000_900),
            measurementSequenceNumber: 11
        )
        let staleCloudRecord = makeRecord(
            macId: sensor.id,
            date: Date(timeIntervalSince1970: 1_700_000_800),
            measurementSequenceNumber: 10
        )
        storage.readAllResult = [sensor.any]
        storage.readLatestResults[sensor.id] = localRecord
        storage.readLastResults[sensor.id] = localRecord
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: sensor.name,
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: nil,
                    picture: nil,
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: timestamp
                ),
                record: staleCloudRecord,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: settings,
            syncState: syncState
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertNil(pool.updatedLastRecord)
        XCTAssertNil(pool.createdRecord)
        XCTAssertEqual(syncState.getSyncStatusLatestRecord(for: sensor.macId!), .complete)
    }

    func testCloudSyncRefreshLatestRecordSkipsHistoryWhenStoredHistoryMacDiffers() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let timestamp = Date(timeIntervalSince1970: 100)
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:86",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: timestamp
        )
        let cloudRecord = makeRecord(
            macId: sensor.id,
            date: Date(timeIntervalSince1970: 1_700_001_000),
            measurementSequenceNumber: 12
        )
        storage.readAllResult = [sensor.any]
        storage.readLatestResults[sensor.id] = nil
        storage.readLastResults[sensor.id] = makeRecord(
            macId: "AA:BB:CC:11:22:99",
            date: Date(timeIntervalSince1970: 1_700_000_900),
            measurementSequenceNumber: 11
        )
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: sensor.name,
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: nil,
                    picture: nil,
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: timestamp
                ),
                record: cloudRecord,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings()
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertEqual(pool.createdLastRecord?.measurementSequenceNumber, 12)
        XCTAssertNil(pool.createdRecord)
    }

    func testCloudSyncRefreshLatestRecordHandlesLocalCloudSensorWithoutMac() async throws {
        let cloud = CloudSpy()
        let storage = StorageSpy()
        storage.readAllResult = [
            makeSensor(luid: "cloud-luid-without-mac", macId: nil, isCloud: true).any,
        ]
        cloud.loadSensorsDenseResult = []
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: makeSettings()
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
    }

    func testCloudSyncRefreshLatestRecordDeletesLocalCloudSensorMissingFromCloud() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:93",
            isCloud: true,
            isClaimed: false,
            isOwner: false
        )
        storage.readAllResult = [sensor.any]
        cloud.loadSensorsDenseResult = []
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings(),
            syncState: syncState
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertEqual(pool.deletedSensors.first?.id, sensor.id)
        XCTAssertNil(syncState.downloadFullHistory(for: sensor.macId))
    }

    func testCloudSyncRefreshLatestRecordHandlesInitialLocalStatusReadFailure() async {
        let cloud = CloudSpy()
        cloud.loadSensorsDenseError = RuuviCloudError.api(.connection)
        let storage = StorageSpy()
        storage.readAllError = NSError(domain: "RuuviServiceTests", code: 90)
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: makeSettings()
        )

        do {
            _ = try await sut.refreshLatestRecord()
            XCTFail("Expected cloud load failure")
        } catch let error as RuuviServiceError {
            guard case .ruuviCloud = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCloudSyncRefreshLatestRecordUnauthorizedPostsAuthorizationNotification() async {
        let cloud = CloudSpy()
        cloud.loadSensorsDenseError = RuuviCloudError.api(.api(.erUnauthorized))
        let notification = expectation(
            forNotification: .NetworkSyncDidFailForAuthorization,
            object: nil
        )
        let sut = makeCoverageCloudSyncService(
            cloud: cloud,
            settings: makeSettings()
        )

        do {
            _ = try await sut.refreshLatestRecord()
            XCTFail("Expected unauthorized error")
        } catch let error as RuuviServiceError {
            guard case let .ruuviCloud(cloudError) = error,
                  case let .api(apiError) = cloudError,
                  case let .api(code) = apiError,
                  code == .erUnauthorized else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [notification], timeout: 1)
    }

    func testCloudSyncDefaultDisplayOrderUpdatesWhenDisplayOrderIsUnchanged() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let timestamp = Date(timeIntervalSince1970: 100)
        let sensor = makeSensor(
            luid: "default-display-luid",
            macId: "AA:BB:CC:11:22:87",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: timestamp
        )
        storage.readAllResult = [sensor.any]
        storage.readSensorSettingsResult = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            description: "unchanged",
            displayOrder: ["temperature"],
            defaultDisplayOrder: true,
            displayOrderLastUpdated: Date(timeIntervalSince1970: 200),
            defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 100),
            descriptionLastUpdated: Date(timeIntervalSince1970: 200)
        )
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: sensor.name,
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: nil,
                    picture: nil,
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: timestamp
                ),
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil,
                settings: RuuviCloudSensorSettings(
                    displayOrderCodes: ["temperature"],
                    defaultDisplayOrder: false,
                    displayOrderLastUpdated: Date(timeIntervalSince1970: 200),
                    defaultDisplayOrderLastUpdated: Date(timeIntervalSince1970: 300),
                    description: "unchanged",
                    descriptionLastUpdated: Date(timeIntervalSince1970: 200)
                )
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings()
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertEqual(pool.displaySettingsCalls.first?.displayOrder, ["temperature"])
        XCTAssertEqual(pool.displaySettingsCalls.first?.defaultDisplayOrder, false)
        XCTAssertNil(pool.descriptionCalls.first)
    }

    func testCloudSyncOffsetSyncUsesFallbackWhenCloudOffsetsAreAlreadyEmpty() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let localTimestamp = Date(timeIntervalSince1970: 100)
        let cloudTimestamp = Date(timeIntervalSince1970: 300)
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:88",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: localTimestamp
        )
        storage.readAllResult = [sensor.any]
        storage.readSensorSettingsResult = nil
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: sensor.name,
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: nil,
                    picture: nil,
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: cloudTimestamp
                ),
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings()
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertTrue(pool.offsetCorrectionCalls.isEmpty)
        XCTAssertEqual(pool.updatedSensors.first?.lastUpdated, cloudTimestamp)
    }

    func testCloudSyncOffsetQueueOmitsValuesAlreadyMatchingCloud() async throws {
        let cloud = CloudSpy()
        let storage = StorageSpy()
        let localTimestamp = Date(timeIntervalSince1970: 300)
        let cloudTimestamp = Date(timeIntervalSince1970: 100)
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:93",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: localTimestamp
        )
        storage.readAllResult = [sensor.any]
        storage.readSensorSettingsResult = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: 1,
            humidityOffset: 0.25,
            pressureOffset: 2
        )
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: sensor.name,
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: nil,
                    picture: nil,
                    offsetTemperature: 1,
                    offsetHumidity: 25,
                    offsetPressure: 200,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: cloudTimestamp
                ),
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: makeSettings()
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertTrue(cloud.updateOffsetCalls.isEmpty)
    }

    func testCloudSyncMarksFullHistoryWhenFreePlanSensorUpgrades() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let localTimestamp = Date(timeIntervalSince1970: 100)
        let cloudTimestamp = Date(timeIntervalSince1970: 300)
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:94",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: localTimestamp
        ).with(ownersPlan: "free")
        storage.readAllResult = [sensor.any]
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: sensor.name,
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: "pro",
                    picture: nil,
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: cloudTimestamp
                ),
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings(),
            syncState: syncState
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertEqual(syncState.downloadFullHistory(for: sensor.macId), true)
        XCTAssertEqual(pool.updatedSensors.first?.ownersPlan, "pro")
    }

    func testCloudSyncUnclaimsLocalSensorMissingFromCloud() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:95",
            isCloud: false,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com"
        )
        storage.readAllResult = [sensor.any]
        cloud.loadSensorsDenseResult = []
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings()
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertEqual(pool.updatedSensors.first?.isClaimed, false)
        XCTAssertEqual(pool.updatedSensors.first?.isOwner, true)
        XCTAssertEqual(pool.updatedSensors.first?.owner, "owner@example.com")
    }

    func testCloudSyncSensorHistoryReturnsEmptyWhenAlreadyInProgress() async throws {
        let cloud = CloudSpy()
        let syncStarted = expectation(description: "history sync started")
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:96",
            isCloud: true
        ).with(maxHistoryDays: 14)
        var releaseLoadRecords: CheckedContinuation<Void, Never>?
        cloud.onLoadRecords = {
            await withCheckedContinuation { continuation in
                releaseLoadRecords = continuation
                syncStarted.fulfill()
            }
        }
        let sut = makeCoverageCloudSyncService(
            cloud: cloud,
            settings: makeSettings(),
            syncState: RuuviLocalSyncStateUserDefaults(),
            repository: RepositorySpy()
        )

        let firstSync = Task {
            try await sut.sync(sensor: sensor)
        }
        await fulfillment(of: [syncStarted], timeout: 1)
        let secondResult = try await sut.sync(sensor: sensor)
        releaseLoadRecords?.resume()
        _ = try await firstSync.value

        XCTAssertTrue(secondResult.isEmpty)
    }

    func testCloudSyncRefreshLatestRecordRunsHistorySyncWhenEnabled() async throws {
        let cloud = CloudSpy()
        let storage = StorageSpy()
        let repository = RepositorySpy()
        let settings = makeSettings()
        settings.historySyncLegacy = true
        let timestamp = Date(timeIntervalSince1970: 100)
        let sensor = makeSensor(
            macId: "AA:BB:CC:11:22:97",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: timestamp
        ).with(maxHistoryDays: 14)
        storage.readAllResult = [sensor.any]
        storage.readLatestResults[sensor.id] = makeRecord(
            macId: sensor.id,
            date: Date(timeIntervalSince1970: 1_700_001_000)
        )
        cloud.loadRecordsResult = [
            makeRecord(
                macId: sensor.id,
                date: Date(timeIntervalSince1970: 1_700_001_100),
                measurementSequenceNumber: 17
            ).any,
        ]
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: sensor.name,
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: nil,
                    picture: nil,
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: 14,
                    lastUpdated: timestamp
                ),
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: settings,
            repository: repository
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        await waitUntil {
            !repository.createdRecords.isEmpty
        }
        XCTAssertEqual(repository.createdRecords.first?.measurementSequenceNumber, 17)
    }

    func testCloudSyncRefreshLatestRecordCreatesHistoryWhenCloudSensorHasNoMacAndHistoryReadFails() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let cloudRecord = makeRecord(
            luid: nil,
            macId: nil,
            date: Date(timeIntervalSince1970: 1_700_001_200),
            measurementSequenceNumber: 18
        )
        storage.readAllResult = []
        storage.readLastError = NSError(domain: "RuuviServiceTests", code: 43)
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: "not-a-mac",
                    serviceUUID: nil,
                    name: "No MAC Sensor",
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: nil,
                    picture: nil,
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: Date(timeIntervalSince1970: 100)
                ),
                record: cloudRecord,
                alerts: CloudSensorAlertsStub(sensor: "not-a-mac", alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: makeSettings()
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertEqual(pool.createdRecord?.measurementSequenceNumber, 18)
    }

    func testCloudSyncQueueImageUpdateReturnsEarlyWhenLocalSensorHasNoMac() async throws {
        let cloud = CloudSpy()
        let storage = StorageSpy()
        let sensor = makeSensor(
            luid: "112289",
            macId: nil,
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: Date(timeIntervalSince1970: 300)
        )
        storage.readAllResult = [sensor.any]
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: "AA:BB:CC:11:22:89",
                    serviceUUID: nil,
                    name: "Cloud",
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: nil,
                    picture: URL(string: "https://example.com/cloud.jpg"),
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: Date(timeIntervalSince1970: 200)
                ),
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: "AA:BB:CC:11:22:89", alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: makeSettings()
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertTrue(cloud.updateNameCalls.isEmpty)
        XCTAssertTrue(cloud.uploadCalls.isEmpty)
        XCTAssertTrue(cloud.resetImageCalls.isEmpty)
    }

    func testCloudSyncQueueImageUpdateSkipsInvalidLocalImageData() async throws {
        let cloud = CloudSpy()
        let storage = StorageSpy()
        let localImages = LocalImagesSpy()
        let sensor = makeSensor(
            luid: "invalid-image-luid",
            macId: "AA:BB:CC:11:22:90",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: Date(timeIntervalSince1970: 300)
        )
        localImages.customBackgrounds[sensor.macId?.value ?? ""] = UIImage()
        storage.readAllResult = [sensor.any]
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: "Cloud",
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: nil,
                    picture: URL(string: "https://example.com/cloud.jpg"),
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: Date(timeIntervalSince1970: 200)
                ),
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: makeSettings(),
            localImages: localImages
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertTrue(cloud.uploadCalls.isEmpty)
        XCTAssertTrue(cloud.resetImageCalls.isEmpty)
    }

    func testCloudSyncQueueImageUpdateSkipsWhenCloudPictureIsAlreadyCached() async throws {
        let cloud = CloudSpy()
        let storage = StorageSpy()
        let localImages = LocalImagesSpy()
        let sensor = makeSensor(
            luid: "cached-image-luid",
            macId: "AA:BB:CC:11:22:91",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: Date(timeIntervalSince1970: 300)
        )
        let cloudSensor = CloudSensorStruct(
            id: sensor.id,
            serviceUUID: nil,
            name: "Cloud",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: nil,
            picture: URL(string: "https://example.com/cloud.jpg"),
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            isCloudSensor: true,
            canShare: true,
            sharedTo: [],
            maxHistoryDays: nil,
            lastUpdated: Date(timeIntervalSince1970: 200)
        )
        localImages.customBackgrounds[sensor.macId?.value ?? ""] = makeImage(color: .blue)
        localImages.setPictureIsCached(for: cloudSensor)
        storage.readAllResult = [sensor.any]
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: cloudSensor,
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            ),
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: makeSettings(),
            localImages: localImages
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertTrue(cloud.uploadCalls.isEmpty)
        XCTAssertTrue(cloud.resetImageCalls.isEmpty)
    }

    func testCloudSyncQueuedRequestKeepsRequestOnNonConflictFailure() async {
        let cloud = CloudSpy()
        cloud.executeQueuedRequestError = RuuviCloudError.api(.connection)
        let pool = PoolSpy()
        let request = makeQueuedRequest(uniqueKey: "non-conflict")
        let sut = makeCoverageCloudSyncService(
            cloud: cloud,
            pool: pool,
            settings: makeSettings()
        )

        do {
            _ = try await sut.syncQueuedRequest(request: request)
            XCTFail("Expected queued request failure")
        } catch let error as RuuviServiceError {
            guard case .ruuviCloud = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(cloud.executedRequests, ["non-conflict"])
        XCTAssertTrue(pool.deletedQueuedRequests.isEmpty)
    }

    func testCloudSyncQueuesCloudImageResetWhenLocalSensorHasNoCustomBackground() async throws {
        let cloud = CloudSpy()
        let storage = StorageSpy()
        let localImages = LocalImagesSpy()
        let settings = makeSettings()
        let sensor = makeSensor(
            luid: "reset-luid",
            macId: "AA:BB:CC:11:22:70",
            name: "Local Reset",
            isCloud: true,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: Date(timeIntervalSince1970: 300)
        )
        let cloudSensor = CloudSensorStruct(
            id: sensor.id,
            serviceUUID: nil,
            name: "Cloud Reset",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "pro",
            picture: URL(string: "https://example.com/cloud-reset.jpg"),
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            isCloudSensor: true,
            canShare: true,
            sharedTo: [],
            maxHistoryDays: nil,
            lastUpdated: Date(timeIntervalSince1970: 200)
        )
        storage.readAllResult = [sensor.any]
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: cloudSensor,
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            )
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: settings,
            localImages: localImages
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        await waitUntil {
            cloud.updateNameCalls.count == 1 && cloud.resetImageCalls.count == 1
        }
        XCTAssertEqual(cloud.resetImageCalls, [sensor.id])
        XCTAssertTrue(cloud.uploadCalls.isEmpty)
    }

    func testCloudSyncQueuesLuidCustomBackgroundWhenMacCustomBackgroundIsMissing() async throws {
        let cloud = CloudSpy()
        let storage = StorageSpy()
        let localImages = LocalImagesSpy()
        let settings = makeSettings()
        let sensor = makeSensor(
            luid: "luid-background",
            macId: "AA:BB:CC:11:22:71",
            name: "Local Background",
            isCloud: true,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: Date(timeIntervalSince1970: 300)
        )
        localImages.customBackgrounds[sensor.luid?.value ?? ""] = makeImage(color: .magenta)
        let cloudSensor = CloudSensorStruct(
            id: sensor.id,
            serviceUUID: nil,
            name: "Cloud Background",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "pro",
            picture: URL(string: "https://example.com/cloud-background.jpg"),
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            isCloudSensor: true,
            canShare: true,
            sharedTo: [],
            maxHistoryDays: nil,
            lastUpdated: Date(timeIntervalSince1970: 200)
        )
        storage.readAllResult = [sensor.any]
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: cloudSensor,
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil
            )
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: settings,
            localImages: localImages
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        await waitUntil {
            cloud.updateNameCalls.count == 1 && cloud.uploadCalls.count == 1
        }
        XCTAssertEqual(cloud.uploadCalls.first?.macId, sensor.id)
        XCTAssertTrue(cloud.resetImageCalls.isEmpty)
    }

    func testCloudSyncDisplaySettingsUseFallbackSettingsWhenLocalSettingsAreMissing() async throws {
        let cloud = CloudSpy()
        let pool = PoolSpy()
        let storage = StorageSpy()
        let settings = makeSettings()
        let sensor = makeSensor(
            luid: "display-fallback-luid",
            macId: "AA:BB:CC:11:22:72",
            isCloud: true,
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: Date(timeIntervalSince1970: 100)
        )
        let cloudSensor = CloudSensorStruct(
            id: sensor.id,
            serviceUUID: nil,
            name: "Display Fallback",
            isClaimed: true,
            isOwner: true,
            owner: "owner@example.com",
            ownersPlan: "pro",
            picture: nil,
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            isCloudSensor: true,
            canShare: true,
            sharedTo: [],
            maxHistoryDays: nil,
            lastUpdated: Date(timeIntervalSince1970: 100)
        )
        storage.readAllResult = [sensor.any]
        storage.readSensorSettingsResult = nil
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: cloudSensor,
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil,
                settings: RuuviCloudSensorSettings(
                    displayOrderCodes: nil,
                    defaultDisplayOrder: nil,
                    displayOrderLastUpdated: nil,
                    defaultDisplayOrderLastUpdated: nil,
                    description: "Cloud-only description",
                    descriptionLastUpdated: Date(timeIntervalSince1970: 200)
                )
            )
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            pool: pool,
            settings: settings
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        XCTAssertEqual(pool.displaySettingsCalls.first?.sensorId, sensor.id)
        XCTAssertEqual(pool.descriptionCalls.first?.description, "Cloud-only description")
        XCTAssertEqual(pool.descriptionCalls.first?.sensorId, sensor.id)
    }

    func testCloudSyncQueuesNilDescriptionAsEmptyStringWhenLocalDescriptionIsNewer() async throws {
        let cloud = CloudSpy()
        let storage = StorageSpy()
        let timestamp = Date(timeIntervalSince1970: 100)
        let sensor = makeSensor(
            luid: "description-local-luid",
            macId: "AA:BB:CC:11:22:75",
            isCloud: true,
            isOwner: true,
            owner: "owner@example.com",
            lastUpdated: timestamp
        )
        storage.readAllResult = [sensor.any]
        storage.readSensorSettingsResult = SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            description: nil,
            descriptionLastUpdated: Date(timeIntervalSince1970: 300)
        )
        cloud.loadSensorsDenseResult = [
            RuuviCloudSensorDense(
                sensor: CloudSensorStruct(
                    id: sensor.id,
                    serviceUUID: nil,
                    name: sensor.name,
                    isClaimed: true,
                    isOwner: true,
                    owner: "owner@example.com",
                    ownersPlan: "pro",
                    picture: nil,
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    isCloudSensor: true,
                    canShare: true,
                    sharedTo: [],
                    maxHistoryDays: nil,
                    lastUpdated: timestamp
                ),
                record: nil,
                alerts: CloudSensorAlertsStub(sensor: sensor.id, alerts: []),
                subscription: nil,
                settings: RuuviCloudSensorSettings(
                    displayOrderCodes: nil,
                    defaultDisplayOrder: nil,
                    displayOrderLastUpdated: nil,
                    defaultDisplayOrderLastUpdated: nil,
                    description: "Cloud description",
                    descriptionLastUpdated: Date(timeIntervalSince1970: 200)
                )
            )
        ]
        let sut = makeCoverageCloudSyncService(
            storage: storage,
            cloud: cloud,
            settings: makeSettings()
        )

        let result = try await sut.refreshLatestRecord()

        XCTAssertTrue(result)
        await waitUntil {
            cloud.updateSensorSettingsCalls.count == 1
        }
        XCTAssertEqual(
            cloud.updateSensorSettingsCalls.first?.types,
            [RuuviCloudApiSetting.sensorDescription.rawValue]
        )
        XCTAssertEqual(cloud.updateSensorSettingsCalls.first?.values, [""])
    }

    func testCloudSyncSyncAllHistoryOnlyProcessesEligibleSensors() async throws {
        let cloud = CloudSpy()
        let storage = StorageSpy()
        let repository = RepositorySpy()
        let settings = makeSettings()
        let syncState = RuuviLocalSyncStateUserDefaults()
        let eligible = makeSensor(macId: "AA:BB:CC:11:22:33", isCloud: true)
            .with(maxHistoryDays: 14)
        let missingLatest = makeSensor(macId: "AA:BB:CC:11:22:44", isCloud: true)
            .with(maxHistoryDays: 14)
        let localOnly = makeSensor(macId: "AA:BB:CC:11:22:55", isCloud: false)
            .with(maxHistoryDays: 14)
        storage.readAllResult = [eligible.any, missingLatest.any, localOnly.any]
        storage.readLatestResults[eligible.id] = makeRecord(macId: eligible.id, measurementSequenceNumber: 1)
        storage.readLatestResults[missingLatest.id] = nil
        cloud.loadRecordsResult = [
            makeRecord(
                macId: eligible.id,
                date: Date(timeIntervalSince1970: 1_700_100_000),
                measurementSequenceNumber: 3
            ).any
        ]
        let sut = RuuviServiceCloudSyncImpl(
            ruuviStorage: storage,
            ruuviCloud: cloud,
            ruuviPool: PoolSpy(),
            ruuviLocalSettings: settings,
            ruuviLocalSyncState: syncState,
            ruuviLocalImages: LocalImagesSpy(),
            ruuviRepository: repository,
            ruuviLocalIDs: RuuviLocalIDsUserDefaults(),
            ruuviAlertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: settings
            ),
            ruuviAppSettingsService: RuuviServiceAppSettingsImpl(cloud: cloud, localSettings: settings)
        )

        let success = try await sut.syncAllHistory()

        XCTAssertTrue(success)
        XCTAssertEqual(repository.createdRecords.count, 1)
        XCTAssertEqual(repository.createdRecords.first?.macId?.value, eligible.macId?.value)
        XCTAssertNotNil(syncState.getSyncDate(for: eligible.macId))
        XCTAssertNil(syncState.getSyncDate(for: missingLatest.macId))
    }

    func testCloudSyncSyncAllRecordsResetsSyncingFlagWhenSettingsSyncFails() async {
        let cloud = CloudSpy()
        cloud.getCloudSettingsResult = nil
        let settings = makeSettings()
        let sut = RuuviServiceCloudSyncImpl(
            ruuviStorage: StorageSpy(),
            ruuviCloud: cloud,
            ruuviPool: PoolSpy(),
            ruuviLocalSettings: settings,
            ruuviLocalSyncState: RuuviLocalSyncStateUserDefaults(),
            ruuviLocalImages: LocalImagesSpy(),
            ruuviRepository: RepositorySpy(),
            ruuviLocalIDs: RuuviLocalIDsUserDefaults(),
            ruuviAlertService: RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: settings
            ),
            ruuviAppSettingsService: RuuviServiceAppSettingsImpl(cloud: cloud, localSettings: settings)
        )

        do {
            _ = try await sut.syncAllRecords()
            XCTFail("Expected sync to fail")
        } catch let error as RuuviServiceError {
            guard case .failedToParseNetworkResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(settings.isSyncing)
    }

    func testAlertSyncCoversCloudAlertTypesAndPersistsConvertedValues() {
        struct CloudAlertCase {
            let alert: CloudAlertStub
            let expectedType: AlertType
            let validate: (RuuviServiceAlertImpl, PhysicalSensor) -> Void
        }

        let settings = makeSettings()
        let localIDs = RuuviLocalIDsUserDefaults()
        let sensor = makeSensor()
        localIDs.set(luid: sensor.luid!, for: sensor.macId!)
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
        let sut = RuuviServiceAlertImpl(
            cloud: CloudSpy(),
            localIDs: localIDs,
            ruuviLocalSettings: settings
        )
        let humidityLow = Humidity(value: 3, unit: .absolute)
        let humidityHigh = Humidity(value: 8, unit: .absolute)
        let alerts: [CloudAlertCase] = [
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .humidity,
                    enabled: true,
                    min: 40,
                    max: 60,
                    counter: nil,
                    delay: nil,
                    description: "RH",
                    triggered: true,
                    triggeredAt: "2024-01-01T00:00:00Z",
                    lastUpdated: nil
                ),
                expectedType: .relativeHumidity(lower: 0.4, upper: 0.6),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerRelativeHumidity(for: sensor), 0.4)
                    XCTAssertEqual(service.upperRelativeHumidity(for: sensor), 0.6)
                    XCTAssertEqual(service.relativeHumidityDescription(for: sensor), "RH")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .humidityAbsolute,
                    enabled: true,
                    min: humidityLow.value,
                    max: humidityHigh.value,
                    counter: nil,
                    delay: nil,
                    description: "Absolute",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .humidity(lower: humidityLow, upper: humidityHigh),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerHumidity(for: sensor)?.value, humidityLow.value)
                    XCTAssertEqual(service.upperHumidity(for: sensor)?.value, humidityHigh.value)
                    XCTAssertEqual(service.humidityDescription(for: sensor), "Absolute")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .dewPoint,
                    enabled: true,
                    min: -5,
                    max: 4,
                    counter: nil,
                    delay: nil,
                    description: "Dew",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .dewPoint(lower: -5, upper: 4),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerDewPoint(for: sensor), -5)
                    XCTAssertEqual(service.upperDewPoint(for: sensor), 4)
                    XCTAssertEqual(service.dewPointDescription(for: sensor), "Dew")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .pressure,
                    enabled: true,
                    min: 99_500,
                    max: 100_500,
                    counter: nil,
                    delay: nil,
                    description: "Pressure",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .pressure(lower: 995, upper: 1005),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerPressure(for: sensor), 995)
                    XCTAssertEqual(service.upperPressure(for: sensor), 1005)
                    XCTAssertEqual(service.pressureDescription(for: sensor), "Pressure")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .signal,
                    enabled: true,
                    min: -100,
                    max: -40,
                    counter: nil,
                    delay: nil,
                    description: "Signal",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .signal(lower: -100, upper: -40),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerSignal(for: sensor), -100)
                    XCTAssertEqual(service.upperSignal(for: sensor), -40)
                    XCTAssertEqual(service.signalDescription(for: sensor), "Signal")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .battery,
                    enabled: true,
                    min: 2.3,
                    max: 3.3,
                    counter: nil,
                    delay: nil,
                    description: "Battery",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .batteryVoltage(lower: 2.3, upper: 3.3),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerBatteryVoltage(for: sensor), 2.3)
                    XCTAssertEqual(service.upperBatteryVoltage(for: sensor), 3.3)
                    XCTAssertEqual(service.batteryVoltageDescription(for: sensor), "Battery")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .aqi,
                    enabled: true,
                    min: 10,
                    max: 90,
                    counter: nil,
                    delay: nil,
                    description: "AQI",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .aqi(lower: 10, upper: 90),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerAQI(for: sensor), 10)
                    XCTAssertEqual(service.upperAQI(for: sensor), 90)
                    XCTAssertEqual(service.aqiDescription(for: sensor), "AQI")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .co2,
                    enabled: true,
                    min: 700,
                    max: 1200,
                    counter: nil,
                    delay: nil,
                    description: "CO2",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .carbonDioxide(lower: 700, upper: 1200),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerCarbonDioxide(for: sensor), 700)
                    XCTAssertEqual(service.upperCarbonDioxide(for: sensor), 1200)
                    XCTAssertEqual(service.carbonDioxideDescription(for: sensor), "CO2")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .pm10,
                    enabled: true,
                    min: 1,
                    max: 4,
                    counter: nil,
                    delay: nil,
                    description: "PM1",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .pMatter1(lower: 1, upper: 4),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerPM1(for: sensor), 1)
                    XCTAssertEqual(service.upperPM1(for: sensor), 4)
                    XCTAssertEqual(service.pm1Description(for: sensor), "PM1")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .pm25,
                    enabled: true,
                    min: 2,
                    max: 5,
                    counter: nil,
                    delay: nil,
                    description: "PM2.5",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .pMatter25(lower: 2, upper: 5),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerPM25(for: sensor), 2)
                    XCTAssertEqual(service.upperPM25(for: sensor), 5)
                    XCTAssertEqual(service.pm25Description(for: sensor), "PM2.5")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .pm40,
                    enabled: true,
                    min: 3,
                    max: 6,
                    counter: nil,
                    delay: nil,
                    description: "PM4",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .pMatter4(lower: 3, upper: 6),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerPM4(for: sensor), 3)
                    XCTAssertEqual(service.upperPM4(for: sensor), 6)
                    XCTAssertEqual(service.pm4Description(for: sensor), "PM4")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .pm100,
                    enabled: true,
                    min: 4,
                    max: 7,
                    counter: nil,
                    delay: nil,
                    description: "PM10",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .pMatter10(lower: 4, upper: 7),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerPM10(for: sensor), 4)
                    XCTAssertEqual(service.upperPM10(for: sensor), 7)
                    XCTAssertEqual(service.pm10Description(for: sensor), "PM10")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .voc,
                    enabled: true,
                    min: 5,
                    max: 8,
                    counter: nil,
                    delay: nil,
                    description: "VOC",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .voc(lower: 5, upper: 8),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerVOC(for: sensor), 5)
                    XCTAssertEqual(service.upperVOC(for: sensor), 8)
                    XCTAssertEqual(service.vocDescription(for: sensor), "VOC")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .nox,
                    enabled: true,
                    min: 6,
                    max: 9,
                    counter: nil,
                    delay: nil,
                    description: "NOX",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .nox(lower: 6, upper: 9),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerNOX(for: sensor), 6)
                    XCTAssertEqual(service.upperNOX(for: sensor), 9)
                    XCTAssertEqual(service.noxDescription(for: sensor), "NOX")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .soundInstant,
                    enabled: true,
                    min: 50,
                    max: 90,
                    counter: nil,
                    delay: nil,
                    description: "Instant",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .soundInstant(lower: 50, upper: 90),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerSoundInstant(for: sensor), 50)
                    XCTAssertEqual(service.upperSoundInstant(for: sensor), 90)
                    XCTAssertEqual(service.soundInstantDescription(for: sensor), "Instant")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .soundAverage,
                    enabled: true,
                    min: 45,
                    max: 70,
                    counter: nil,
                    delay: nil,
                    description: "Average",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .soundAverage(lower: 45, upper: 70),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerSoundAverage(for: sensor), 45)
                    XCTAssertEqual(service.upperSoundAverage(for: sensor), 70)
                    XCTAssertEqual(service.soundAverageDescription(for: sensor), "Average")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .soundPeak,
                    enabled: true,
                    min: 75,
                    max: 110,
                    counter: nil,
                    delay: nil,
                    description: "Peak",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .soundPeak(lower: 75, upper: 110),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerSoundPeak(for: sensor), 75)
                    XCTAssertEqual(service.upperSoundPeak(for: sensor), 110)
                    XCTAssertEqual(service.soundPeakDescription(for: sensor), "Peak")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .luminosity,
                    enabled: true,
                    min: 100,
                    max: 900,
                    counter: nil,
                    delay: nil,
                    description: "Light",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .luminosity(lower: 100, upper: 900),
                validate: { service, sensor in
                    XCTAssertEqual(service.lowerLuminosity(for: sensor), 100)
                    XCTAssertEqual(service.upperLuminosity(for: sensor), 900)
                    XCTAssertEqual(service.luminosityDescription(for: sensor), "Light")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .offline,
                    enabled: true,
                    min: 0,
                    max: 1800,
                    counter: nil,
                    delay: 0,
                    description: "Cloud",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .cloudConnection(unseenDuration: 1800),
                validate: { service, sensor in
                    XCTAssertEqual(service.cloudConnectionUnseenDuration(for: sensor), 1800)
                    XCTAssertEqual(service.cloudConnectionDescription(for: sensor), "Cloud")
                }
            ),
            CloudAlertCase(
                alert: CloudAlertStub(
                    type: .movement,
                    enabled: true,
                    min: nil,
                    max: nil,
                    counter: 12,
                    delay: nil,
                    description: "Move",
                    triggered: nil,
                    triggeredAt: nil,
                    lastUpdated: nil
                ),
                expectedType: .movement(last: 12),
                validate: { service, sensor in
                    XCTAssertEqual(service.movementCounter(for: sensor), 12)
                    XCTAssertEqual(service.movementDescription(for: sensor), "Move")
                }
            ),
        ]

        for entry in alerts {
            sut.sync(cloudAlerts: [
                CloudSensorAlertsStub(sensor: sensor.macId?.value, alerts: [entry.alert])
            ])
            XCTAssertTrue(sut.isOn(type: entry.expectedType, for: physicalSensor))
            entry.validate(sut, physicalSensor)
        }
    }

    func testAlertSyncQueuesLocalStateToCloudWhenLocalAlertIsNewer() async {
        let cloud = CloudSpy()
        let settings = makeSettings()
        let localIDs = RuuviLocalIDsUserDefaults()
        let sensor = makeSensor(isCloud: true)
        localIDs.set(luid: sensor.luid!, for: sensor.macId!)
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
        let sut = RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: localIDs,
            ruuviLocalSettings: settings
        )
        sut.register(type: .relativeHumidity(lower: 0.2, upper: 0.7), ruuviTag: sensor)
        sut.setRelativeHumidity(description: "Local humidity", ruuviTag: sensor)
        await waitUntil {
            cloud.setAlertCalls.count >= 2
        }
        cloud.setAlertCalls.removeAll()

        sut.sync(cloudAlerts: [
            CloudSensorAlertsStub(
                sensor: sensor.macId?.value,
                alerts: [
                    CloudAlertStub(
                        type: .humidity,
                        enabled: false,
                        min: 10,
                        max: 20,
                        counter: nil,
                        delay: nil,
                        description: "Old cloud",
                        triggered: nil,
                        triggeredAt: nil,
                        lastUpdated: Date(timeIntervalSince1970: 1)
                    )
                ]
            )
        ])

        await waitUntil {
            !cloud.setAlertCalls.isEmpty
        }
        XCTAssertTrue(sut.isOn(type: .relativeHumidity(lower: 0.2, upper: 0.7), for: physicalSensor))
        XCTAssertEqual(cloud.setAlertCalls.first?.type, .humidity)
        XCTAssertEqual(cloud.setAlertCalls.first?.isEnabled, true)
        XCTAssertEqual(cloud.setAlertCalls.first?.min, 20)
        XCTAssertEqual(cloud.setAlertCalls.first?.max, 70)
        XCTAssertEqual(cloud.setAlertCalls.first?.description, "Local humidity")
    }

    func testAlertSyncQueuesRemainingLocalStatesToCloudWhenLocalAlertsAreNewer() async {
        for (index, entry) in alertQueueCases().enumerated() {
            let cloud = CloudSpy()
            let settings = makeSettings()
            let localIDs = RuuviLocalIDsUserDefaults()
            let sensor = makeSensor(
                luid: "queue-luid-\(index)",
                macId: formattedMacAddress(index: index),
                isCloud: false
            )
            localIDs.set(luid: sensor.luid!, for: sensor.macId!)
            let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
            let sut = RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: localIDs,
                ruuviLocalSettings: settings
            )

            entry.registerLocal(sut, sensor, physicalSensor)

            sut.sync(cloudAlerts: [
                CloudSensorAlertsStub(
                    sensor: sensor.macId?.value,
                    alerts: [entry.staleCloudAlert]
                )
            ])

            await waitUntil { cloud.setAlertCalls.count == 1 }

            XCTAssertTrue(sut.isOn(type: entry.expectedType, for: physicalSensor))
            assertAlertCall(
                cloud.setAlertCalls[0],
                type: entry.cloudType,
                settingType: .state,
                isEnabled: true,
                min: entry.expectedMin,
                max: entry.expectedMax,
                counter: entry.expectedCounter,
                delay: entry.expectedDelay,
                description: entry.expectedDescription
            )
        }
    }

    func testAlertSyncDisabledCloudAlertRemovesLocalRegistrationWhenCloudWins() {
        let localIDs = RuuviLocalIDsUserDefaults()
        let sensor = makeSensor()
        localIDs.set(luid: sensor.luid!, for: sensor.macId!)
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
        let sut = RuuviServiceAlertImpl(
            cloud: CloudSpy(),
            localIDs: localIDs,
            ruuviLocalSettings: makeSettings()
        )
        let alert = AlertType.temperature(lower: -1, upper: 5)

        sut.register(type: alert, ruuviTag: sensor)
        sut.setTemperature(description: "local-temperature", ruuviTag: sensor)
        XCTAssertTrue(sut.isOn(type: alert, for: physicalSensor))

        sut.sync(cloudAlerts: [
            CloudSensorAlertsStub(
                sensor: sensor.macId?.value,
                alerts: [
                    CloudAlertStub(
                        type: .temperature,
                        enabled: false,
                        min: -3,
                        max: 7,
                        counter: nil,
                        delay: nil,
                        description: "cloud-disabled",
                        triggered: nil,
                        triggeredAt: nil,
                        lastUpdated: nil
                    )
                ]
            )
        ])

        XCTAssertFalse(sut.isOn(type: alert, for: physicalSensor))
        XCTAssertEqual(sut.temperatureDescription(for: physicalSensor), "cloud-disabled")
    }

    func testAlertSyncWithMatchingTimestampsLeavesLocalStateUntouched() async {
        let cloud = CloudSpy()
        let localIDs = RuuviLocalIDsUserDefaults()
        let sensor = makeSensor()
        localIDs.set(luid: sensor.luid!, for: sensor.macId!)
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
        let sut = RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: localIDs,
            ruuviLocalSettings: makeSettings()
        )
        let alert = AlertType.temperature(lower: -1, upper: 5)
        let syncedAt = Date(timeIntervalSince1970: 1_710_000_000)

        sut.register(type: alert, ruuviTag: sensor)
        sut.setTemperature(description: "local-temperature", ruuviTag: sensor)
        setAlertUpdatedAt(syncedAt, type: alert, for: physicalSensor)
        cloud.setAlertCalls.removeAll()

        sut.sync(cloudAlerts: [
            CloudSensorAlertsStub(
                sensor: sensor.macId?.value,
                alerts: [
                    CloudAlertStub(
                        type: .temperature,
                        enabled: false,
                        min: -10,
                        max: 10,
                        counter: nil,
                        delay: nil,
                        description: "cloud-temperature",
                        triggered: nil,
                        triggeredAt: nil,
                        lastUpdated: syncedAt
                    )
                ]
            )
        ])

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(cloud.setAlertCalls.isEmpty)
        XCTAssertTrue(sut.isOn(type: alert, for: physicalSensor))
        XCTAssertEqual(sut.temperatureDescription(for: physicalSensor), "local-temperature")
    }

    func testAlertRegisterAndUnregisterCoverAllCloudBackedTypes() async {
        struct RegisterCase {
            let type: AlertType
            let cloudType: RuuviCloudAlertType?
            let min: Double?
            let max: Double?
            let counter: Int?
            let delay: Int?
        }

        let cloud = CloudSpy()
        let sensor = makeSensor(isCloud: true)
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
        let sut = RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: RuuviLocalIDsUserDefaults(),
            ruuviLocalSettings: makeSettings()
        )
        let absoluteLow = Humidity(value: 2.5, unit: .absolute)
        let absoluteHigh = Humidity(value: 6.5, unit: .absolute)
        let cases: [RegisterCase] = [
            .init(type: .temperature(lower: -1, upper: 5), cloudType: .temperature, min: -1, max: 5, counter: nil, delay: nil),
            .init(type: .relativeHumidity(lower: 0.2, upper: 0.7), cloudType: .humidity, min: 20, max: 70, counter: nil, delay: nil),
            .init(type: .humidity(lower: absoluteLow, upper: absoluteHigh), cloudType: .humidityAbsolute, min: absoluteLow.value, max: absoluteHigh.value, counter: nil, delay: nil),
            .init(type: .dewPoint(lower: -5, upper: 1), cloudType: .dewPoint, min: -5, max: 1, counter: nil, delay: nil),
            .init(type: .pressure(lower: 995, upper: 1005), cloudType: .pressure, min: 99_500, max: 100_500, counter: nil, delay: nil),
            .init(type: .signal(lower: -95, upper: -40), cloudType: .signal, min: -95, max: -40, counter: nil, delay: nil),
            .init(type: .batteryVoltage(lower: 2.3, upper: 3.1), cloudType: .battery, min: 2.3, max: 3.1, counter: nil, delay: nil),
            .init(type: .aqi(lower: 10, upper: 90), cloudType: .aqi, min: 10, max: 90, counter: nil, delay: nil),
            .init(type: .carbonDioxide(lower: 600, upper: 1000), cloudType: .co2, min: 600, max: 1000, counter: nil, delay: nil),
            .init(type: .pMatter1(lower: 1, upper: 4), cloudType: .pm10, min: 1, max: 4, counter: nil, delay: nil),
            .init(type: .pMatter25(lower: 2, upper: 5), cloudType: .pm25, min: 2, max: 5, counter: nil, delay: nil),
            .init(type: .pMatter4(lower: 3, upper: 6), cloudType: .pm40, min: 3, max: 6, counter: nil, delay: nil),
            .init(type: .pMatter10(lower: 4, upper: 7), cloudType: .pm100, min: 4, max: 7, counter: nil, delay: nil),
            .init(type: .voc(lower: 5, upper: 8), cloudType: .voc, min: 5, max: 8, counter: nil, delay: nil),
            .init(type: .nox(lower: 6, upper: 9), cloudType: .nox, min: 6, max: 9, counter: nil, delay: nil),
            .init(type: .soundInstant(lower: 45, upper: 90), cloudType: .soundInstant, min: 45, max: 90, counter: nil, delay: nil),
            .init(type: .soundAverage(lower: 40, upper: 80), cloudType: .soundAverage, min: 40, max: 80, counter: nil, delay: nil),
            .init(type: .soundPeak(lower: 60, upper: 110), cloudType: .soundPeak, min: 60, max: 110, counter: nil, delay: nil),
            .init(type: .luminosity(lower: 100, upper: 900), cloudType: .luminosity, min: 100, max: 900, counter: nil, delay: nil),
            .init(type: .connection, cloudType: nil, min: nil, max: nil, counter: nil, delay: nil),
            .init(type: .cloudConnection(unseenDuration: 1800), cloudType: .offline, min: 0, max: 1800, counter: nil, delay: 0),
            .init(type: .movement(last: 12), cloudType: .movement, min: nil, max: nil, counter: 12, delay: nil),
        ]

        for entry in cases {
            cloud.setAlertCalls.removeAll()
            sut.register(type: entry.type, ruuviTag: sensor)
            XCTAssertTrue(sut.isOn(type: entry.type, for: physicalSensor), "Expected alert on for \(entry.type)")

            if entry.cloudType != nil {
                await waitUntil { cloud.setAlertCalls.count == 1 }
                assertAlertCall(
                    cloud.setAlertCalls[0],
                    type: entry.cloudType,
                    settingType: .state,
                    isEnabled: true,
                    min: entry.min,
                    max: entry.max,
                    counter: entry.counter,
                    delay: entry.delay
                )
            } else {
                try? await Task.sleep(nanoseconds: 50_000_000)
                XCTAssertTrue(cloud.setAlertCalls.isEmpty)
            }

            cloud.setAlertCalls.removeAll()
            sut.unregister(type: entry.type, ruuviTag: sensor)
            XCTAssertFalse(sut.isOn(type: entry.type, for: physicalSensor), "Expected alert off for \(entry.type)")

            if entry.cloudType != nil {
                await waitUntil { cloud.setAlertCalls.count == 1 }
                assertAlertCall(
                    cloud.setAlertCalls[0],
                    type: entry.cloudType,
                    settingType: .state,
                    isEnabled: false,
                    min: entry.min,
                    max: entry.max,
                    counter: entry.counter,
                    delay: entry.delay
                )
            } else {
                try? await Task.sleep(nanoseconds: 50_000_000)
                XCTAssertTrue(cloud.setAlertCalls.isEmpty)
            }
        }
    }

    func testAlertScalarBoundAndDescriptionMutatorsPushCloudUpdates() async {
        let cloud = CloudSpy()
        let sensor = makeSensor(isCloud: true)
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
        let sut = RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: RuuviLocalIDsUserDefaults(),
            ruuviLocalSettings: makeSettings()
        )

        for entry in scalarAlertMutationCases() {
            cloud.setAlertCalls.removeAll()
            sut.register(type: entry.makeAlert(entry.initialLower, entry.initialUpper), ruuviTag: sensor)
            await waitUntil { cloud.setAlertCalls.count == 1 }
            cloud.setAlertCalls.removeAll()

            entry.setLower(sut, entry.updatedLower, sensor)
            await waitUntil { cloud.setAlertCalls.count == 1 }
            assertAlertCall(
                cloud.setAlertCalls[0],
                type: entry.cloudType,
                settingType: .lowerBound,
                isEnabled: true,
                min: entry.transform(entry.updatedLower),
                max: entry.transform(entry.initialUpper),
                counter: nil,
                delay: nil
            )
            XCTAssertEqual(entry.lowerGetter(sut, physicalSensor) ?? 0, entry.updatedLower, accuracy: 0.0001)

            cloud.setAlertCalls.removeAll()
            entry.setUpper(sut, entry.updatedUpper, sensor)
            await waitUntil { cloud.setAlertCalls.count == 1 }
            assertAlertCall(
                cloud.setAlertCalls[0],
                type: entry.cloudType,
                settingType: .upperBound,
                isEnabled: true,
                min: entry.transform(entry.updatedLower),
                max: entry.transform(entry.updatedUpper),
                counter: nil,
                delay: nil
            )
            XCTAssertEqual(entry.upperGetter(sut, physicalSensor) ?? 0, entry.updatedUpper, accuracy: 0.0001)

            cloud.setAlertCalls.removeAll()
            let description = "description-\(entry.name)"
            entry.setDescription(sut, description, sensor)
            await waitUntil { cloud.setAlertCalls.count == 1 }
            assertAlertCall(
                cloud.setAlertCalls[0],
                type: entry.cloudType,
                settingType: .description,
                isEnabled: true,
                min: entry.transform(entry.updatedLower),
                max: entry.transform(entry.updatedUpper),
                counter: nil,
                delay: nil,
                description: description
            )
            XCTAssertEqual(entry.descriptionGetter(sut, physicalSensor), description)

            cloud.setAlertCalls.removeAll()
            sut.unregister(type: entry.makeAlert(entry.updatedLower, entry.updatedUpper), ruuviTag: sensor)
            await waitUntil { cloud.setAlertCalls.count == 1 }
        }
    }

    func testAlertScalarCloudMutatorsUseFallbackBoundsWhenValuesAreMissing() async {
        for (index, entry) in scalarAlertMutationCases().enumerated() {
            let cloud = CloudSpy()
            let caseSut = RuuviServiceAlertImpl(
                cloud: cloud,
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: makeSettings()
            )

            let lowerSensor = makeSensor(
                luid: "missing-upper-\(entry.name)",
                macId: formattedMacAddress(index: 20 + index),
                isCloud: true
            )
            entry.setLower(caseSut, nil, lowerSensor)
            await waitUntil { cloud.setAlertCalls.count == 1 }
            XCTAssertEqual(cloud.setAlertCalls[0].type, entry.cloudType)
            XCTAssertEqual(cloud.setAlertCalls[0].settingType, .lowerBound)
            XCTAssertFalse(cloud.setAlertCalls[0].isEnabled)

            cloud.setAlertCalls.removeAll()
            let upperSensor = makeSensor(
                luid: "missing-lower-\(entry.name)",
                macId: formattedMacAddress(index: 60 + index),
                isCloud: true
            )
            entry.setUpper(caseSut, nil, upperSensor)
            await waitUntil { cloud.setAlertCalls.count == 1 }
            XCTAssertEqual(cloud.setAlertCalls[0].type, entry.cloudType)
            XCTAssertEqual(cloud.setAlertCalls[0].settingType, .upperBound)
            XCTAssertFalse(cloud.setAlertCalls[0].isEnabled)

            cloud.setAlertCalls.removeAll()
            let descriptionSensor = makeSensor(
                luid: "missing-bounds-\(entry.name)",
                macId: formattedMacAddress(index: 100 + index),
                isCloud: true
            )
            let description = "missing-bounds-\(entry.name)"
            entry.setDescription(caseSut, description, descriptionSensor)
            await waitUntil { cloud.setAlertCalls.count == 1 }
            XCTAssertEqual(cloud.setAlertCalls[0].type, entry.cloudType)
            XCTAssertEqual(cloud.setAlertCalls[0].settingType, .description)
            XCTAssertFalse(cloud.setAlertCalls[0].isEnabled)
            XCTAssertEqual(cloud.setAlertCalls[0].description, description)
        }
    }

    func testAlertPhysicalSensorAccessorsFallBackFromMissingLuidToMacValues() {
        let sut = RuuviServiceAlertImpl(
            cloud: CloudSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            ruuviLocalSettings: makeSettings()
        )

        for (index, entry) in scalarAlertMutationCases().enumerated() {
            let macOnlySensor = makeSensor(
                luid: nil,
                macId: formattedMacAddress(index: 140 + index)
            )
            let fallbackSensor = PhysicalSensorStruct(
                luid: "fallback-luid-\(entry.name)".luid,
                macId: macOnlySensor.macId
            )
            let description = "fallback-\(entry.name)"

            sut.register(type: entry.makeAlert(entry.initialLower, entry.initialUpper), ruuviTag: macOnlySensor)
            entry.setDescription(sut, description, macOnlySensor)

            XCTAssertEqual(entry.lowerGetter(sut, fallbackSensor) ?? 0, entry.initialLower, accuracy: 0.0001)
            XCTAssertEqual(entry.upperGetter(sut, fallbackSensor) ?? 0, entry.initialUpper, accuracy: 0.0001)
            XCTAssertEqual(entry.descriptionGetter(sut, fallbackSensor), description)
        }

        let macOnlySensor = makeSensor(luid: nil, macId: "AA:BB:CC:44:55:66")
        let fallbackSensor = PhysicalSensorStruct(
            luid: "fallback-special".luid,
            macId: macOnlySensor.macId
        )
        let lowHumidity = Humidity(value: 2.5, unit: .absolute)
        let highHumidity = Humidity(value: 6.5, unit: .absolute)

        sut.register(type: .humidity(lower: lowHumidity, upper: highHumidity), ruuviTag: macOnlySensor)
        sut.setHumidity(description: "fallback-humidity", for: macOnlySensor)
        XCTAssertEqual(sut.lowerHumidity(for: fallbackSensor)?.value ?? 0, lowHumidity.value, accuracy: 0.0001)
        XCTAssertEqual(sut.upperHumidity(for: fallbackSensor)?.value ?? 0, highHumidity.value, accuracy: 0.0001)
        XCTAssertEqual(sut.humidityDescription(for: fallbackSensor), "fallback-humidity")

        sut.register(type: .connection, ruuviTag: macOnlySensor)
        sut.setConnection(description: "fallback-connection", for: macOnlySensor)
        XCTAssertEqual(sut.connectionDescription(for: fallbackSensor), "fallback-connection")

        sut.register(type: .cloudConnection(unseenDuration: 600), ruuviTag: macOnlySensor)
        sut.setCloudConnection(description: "fallback-cloud", for: macOnlySensor)
        XCTAssertEqual(sut.cloudConnectionUnseenDuration(for: fallbackSensor), 600)
        XCTAssertEqual(sut.cloudConnectionDescription(for: fallbackSensor), "fallback-cloud")

        sut.register(type: .movement(last: 4), ruuviTag: macOnlySensor)
        sut.setMovement(description: "fallback-movement", for: macOnlySensor)
        XCTAssertEqual(sut.movementCounter(for: fallbackSensor), 4)
        XCTAssertEqual(sut.movementDescription(for: fallbackSensor), "fallback-movement")

        let alert = AlertType.temperature(lower: -1, upper: 5)
        let mutedTill = Date(timeIntervalSince1970: 1_720_100_000)
        let triggeredAt = "2026-04-20T00:00:00Z"
        sut.register(type: alert, ruuviTag: macOnlySensor)
        sut.mute(type: alert, for: macOnlySensor, till: mutedTill)
        sut.trigger(
            type: alert,
            trigerred: true,
            trigerredAt: triggeredAt,
            for: macOnlySensor
        )
        XCTAssertEqual(sut.mutedTill(type: alert, for: fallbackSensor), mutedTill)
        XCTAssertEqual(sut.triggeredAt(for: fallbackSensor, of: alert), triggeredAt)
        XCTAssertEqual(sut.mutedTill(type: alert, for: macOnlySensor.macId!.value), mutedTill)
    }

    func testAlertSpecialCloudMutatorsUseFallbackBoundsWhenValuesAreMissing() async {
        let cloud = CloudSpy()
        let sensor = makeSensor(
            luid: "missing-special",
            macId: "AA:BB:CC:44:55:77",
            isCloud: true
        )
        let sut = RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: RuuviLocalIDsUserDefaults(),
            ruuviLocalSettings: makeSettings()
        )

        sut.setLower(humidity: nil, for: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        assertAlertCall(
            cloud.setAlertCalls[0],
            type: .humidityAbsolute,
            settingType: .lowerBound,
            isEnabled: false,
            min: 0,
            max: 0,
            counter: nil,
            delay: nil
        )

        cloud.setAlertCalls.removeAll()
        sut.setUpper(humidity: nil, for: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        assertAlertCall(
            cloud.setAlertCalls[0],
            type: .humidityAbsolute,
            settingType: .upperBound,
            isEnabled: false,
            min: 0,
            max: 0,
            counter: nil,
            delay: nil
        )

        cloud.setAlertCalls.removeAll()
        sut.setHumidity(description: "missing-humidity", for: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        assertAlertCall(
            cloud.setAlertCalls[0],
            type: .humidityAbsolute,
            settingType: .description,
            isEnabled: false,
            min: 0,
            max: 0,
            counter: nil,
            delay: nil,
            description: "missing-humidity"
        )

        cloud.setAlertCalls.removeAll()
        sut.setCloudConnection(description: "missing-cloud", ruuviTag: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        assertAlertCall(
            cloud.setAlertCalls[0],
            type: .offline,
            settingType: .description,
            isEnabled: false,
            min: 0,
            max: 600,
            counter: nil,
            delay: 0,
            description: "missing-cloud"
        )
    }

    func testAlertSpecialMutatorsCoverAbsoluteHumidityCloudConnectionMovementAndConnection() async {
        let cloud = CloudSpy()
        let sensor = makeSensor(isCloud: true)
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
        let sut = RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: RuuviLocalIDsUserDefaults(),
            ruuviLocalSettings: makeSettings()
        )

        let initialHumidityLow = Humidity(value: 2.5, unit: .absolute)
        let initialHumidityHigh = Humidity(value: 6.5, unit: .absolute)
        let updatedHumidityLow = Humidity(value: 3.0, unit: .absolute)
        let updatedHumidityHigh = Humidity(value: 7.5, unit: .absolute)
        sut.register(type: .humidity(lower: initialHumidityLow, upper: initialHumidityHigh), ruuviTag: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        cloud.setAlertCalls.removeAll()

        sut.setLower(humidity: updatedHumidityLow, for: physicalSensor)
        XCTAssertEqual(sut.lowerHumidity(for: physicalSensor)?.value ?? 0, updatedHumidityLow.value, accuracy: 0.0001)

        sut.setUpper(humidity: updatedHumidityHigh, for: physicalSensor)
        XCTAssertEqual(sut.upperHumidity(for: physicalSensor)?.value ?? 0, updatedHumidityHigh.value, accuracy: 0.0001)

        sut.setHumidity(description: "absolute-humidity", for: physicalSensor)
        XCTAssertEqual(sut.humidityDescription(for: physicalSensor), "absolute-humidity")

        cloud.setAlertCalls.removeAll()
        sut.register(type: .cloudConnection(unseenDuration: 600), ruuviTag: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        cloud.setAlertCalls.removeAll()

        sut.setCloudConnection(unseenDuration: 1200, ruuviTag: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        assertAlertCall(
            cloud.setAlertCalls[0],
            type: .offline,
            settingType: .delay,
            isEnabled: true,
            min: 0,
            max: 1200,
            counter: nil,
            delay: 0
        )
        XCTAssertEqual(sut.cloudConnectionUnseenDuration(for: physicalSensor) ?? 0, 1200, accuracy: 0.0001)

        cloud.setAlertCalls.removeAll()
        sut.setCloudConnection(description: "offline", ruuviTag: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        assertAlertCall(
            cloud.setAlertCalls[0],
            type: .offline,
            settingType: .description,
            isEnabled: true,
            min: 0,
            max: 1200,
            counter: nil,
            delay: 0,
            description: "offline"
        )
        XCTAssertEqual(sut.cloudConnectionDescription(for: physicalSensor), "offline")

        cloud.setAlertCalls.removeAll()
        sut.register(type: .movement(last: 4), ruuviTag: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        cloud.setAlertCalls.removeAll()

        sut.setMovement(description: "movement", ruuviTag: sensor)
        await waitUntil { cloud.setAlertCalls.count == 1 }
        assertAlertCall(
            cloud.setAlertCalls[0],
            type: .movement,
            settingType: .description,
            isEnabled: true,
            min: nil,
            max: nil,
            counter: nil,
            delay: nil,
            description: "movement"
        )
        XCTAssertEqual(sut.movementDescription(for: physicalSensor), "movement")

        sut.setMovement(counter: 9, for: physicalSensor)
        XCTAssertEqual(sut.movementCounter(for: physicalSensor), 9)

        cloud.setAlertCalls.removeAll()
        sut.register(type: .connection, ruuviTag: sensor)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(cloud.setAlertCalls.isEmpty)
        sut.setConnection(description: "connected", for: physicalSensor)
        XCTAssertEqual(sut.connectionDescription(for: physicalSensor), "connected")
    }

    func testAlertScalarUuidAccessorsMirrorPhysicalSensorState() {
        let sensor = makeSensor()
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
        let uuid = sensor.luid!.value
        let sut = RuuviServiceAlertImpl(
            cloud: CloudSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            ruuviLocalSettings: makeSettings()
        )

        for entry in scalarAlertMutationCases() {
            let description = "uuid-\(entry.name)"
            let alert = entry.makeAlert(entry.initialLower, entry.initialUpper)

            sut.register(type: alert, ruuviTag: sensor)
            entry.setDescription(sut, description, sensor)

            XCTAssertEqual(entry.lowerGetter(sut, physicalSensor) ?? 0, entry.initialLower, accuracy: 0.0001)
            XCTAssertEqual(entry.upperGetter(sut, physicalSensor) ?? 0, entry.initialUpper, accuracy: 0.0001)
            XCTAssertEqual(entry.descriptionGetter(sut, physicalSensor), description)
            XCTAssertEqual(uuidLowerValue(for: entry.name, from: sut, uuid: uuid) ?? 0, entry.initialLower, accuracy: 0.0001)
            XCTAssertEqual(uuidUpperValue(for: entry.name, from: sut, uuid: uuid) ?? 0, entry.initialUpper, accuracy: 0.0001)
            XCTAssertEqual(uuidDescriptionValue(for: entry.name, from: sut, uuid: uuid), description)

            sut.unregister(type: alert, ruuviTag: sensor)
        }
    }

    func testAlertUuidAccessorsMuteTriggerAndRegistrationState() {
        let sensor = makeSensor()
        let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
        let uuid = sensor.luid!.value
        let sut = RuuviServiceAlertImpl(
            cloud: CloudSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            ruuviLocalSettings: makeSettings()
        )

        let absoluteHumidityLow = Humidity(value: 2.5, unit: .absolute)
        let absoluteHumidityHigh = Humidity(value: 6.5, unit: .absolute)
        sut.register(type: .humidity(lower: absoluteHumidityLow, upper: absoluteHumidityHigh), ruuviTag: sensor)
        sut.setHumidity(description: "absolute-humidity", for: physicalSensor)
        XCTAssertEqual(sut.lowerHumidity(for: uuid)?.value ?? 0, absoluteHumidityLow.value, accuracy: 0.0001)
        XCTAssertEqual(sut.upperHumidity(for: uuid)?.value ?? 0, absoluteHumidityHigh.value, accuracy: 0.0001)
        XCTAssertEqual(sut.humidityDescription(for: uuid), "absolute-humidity")

        sut.register(type: .connection, ruuviTag: sensor)
        sut.setConnection(description: "connected", for: physicalSensor)
        XCTAssertEqual(sut.connectionDescription(for: uuid), "connected")

        sut.register(type: .cloudConnection(unseenDuration: 600), ruuviTag: sensor)
        sut.setCloudConnection(description: "offline", for: physicalSensor)
        XCTAssertEqual(sut.cloudConnectionDescription(for: physicalSensor), "offline")

        sut.register(type: .movement(last: 4), ruuviTag: sensor)
        sut.setMovement(description: "movement", for: physicalSensor)
        sut.setMovement(counter: 9, for: uuid)
        XCTAssertEqual(sut.movementCounter(for: uuid), 9)
        XCTAssertEqual(sut.movementDescription(for: uuid), "movement")

        let registrationSensor = makeSensor(
            luid: "luid-registration",
            macId: "AA:BB:CC:44:55:66"
        )
        let registrationPhysicalSensor = PhysicalSensorStruct(
            luid: registrationSensor.luid,
            macId: registrationSensor.macId
        )
        let registrationUUID = registrationSensor.luid!.value
        let alert = AlertType.temperature(lower: -1, upper: 5)
        let mutedTill = Date(timeIntervalSince1970: 1_710_000_000)
        let triggeredAt = "2026-04-17T00:00:00Z"

        sut.register(type: alert, ruuviTag: registrationSensor)
        XCTAssertTrue(sut.hasRegistrations(for: registrationUUID))

        sut.mute(type: alert, for: registrationPhysicalSensor, till: mutedTill)
        XCTAssertEqual(sut.mutedTill(type: alert, for: registrationPhysicalSensor), mutedTill)

        sut.trigger(
            type: alert,
            trigerred: true,
            trigerredAt: triggeredAt,
            for: registrationPhysicalSensor
        )
        XCTAssertEqual(sut.triggered(for: registrationPhysicalSensor, of: alert), true)
        XCTAssertEqual(sut.triggeredAt(for: registrationPhysicalSensor, of: alert), triggeredAt)

        sut.unmute(type: alert, for: registrationPhysicalSensor)
        XCTAssertNil(sut.mutedTill(type: alert, for: registrationPhysicalSensor))

        sut.unregister(type: alert, ruuviTag: registrationSensor)
        XCTAssertFalse(sut.hasRegistrations(for: registrationUUID))
    }

    func testAlertScalarMutatorsSupportSingleIdentifierSensors() {
        for kind in SingleIdentifierKind.allCases {
            for (index, entry) in scalarAlertMutationCases().enumerated() {
                let sensor = makeSingleIdentifierSensor(kind: kind, index: index)
                let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
                let identifier = primaryIdentifier(for: physicalSensor)
                let sut = RuuviServiceAlertImpl(
                    cloud: CloudSpy(),
                    localIDs: RuuviLocalIDsUserDefaults(),
                    ruuviLocalSettings: makeSettings()
                )
                let initialAlert = entry.makeAlert(entry.initialLower, entry.initialUpper)
                let updatedAlert = entry.makeAlert(entry.updatedLower, entry.updatedUpper)
                let description = "\(kind.rawValue)-\(entry.name)"

                sut.register(type: initialAlert, ruuviTag: sensor)
                entry.setLower(sut, entry.updatedLower, sensor)
                entry.setUpper(sut, entry.updatedUpper, sensor)
                entry.setDescription(sut, description, sensor)

                XCTAssertTrue(sut.isOn(type: updatedAlert, for: physicalSensor))
                XCTAssertEqual(entry.lowerGetter(sut, physicalSensor) ?? 0, entry.updatedLower, accuracy: 0.0001)
                XCTAssertEqual(entry.upperGetter(sut, physicalSensor) ?? 0, entry.updatedUpper, accuracy: 0.0001)
                XCTAssertEqual(entry.descriptionGetter(sut, physicalSensor), description)
                XCTAssertEqual(uuidLowerValue(for: entry.name, from: sut, uuid: identifier) ?? 0, entry.updatedLower, accuracy: 0.0001)
                XCTAssertEqual(uuidUpperValue(for: entry.name, from: sut, uuid: identifier) ?? 0, entry.updatedUpper, accuracy: 0.0001)
                XCTAssertEqual(uuidDescriptionValue(for: entry.name, from: sut, uuid: identifier), description)

                sut.unregister(type: updatedAlert, ruuviTag: sensor)
                XCTAssertFalse(sut.hasRegistrations(for: physicalSensor))
            }
        }
    }

    func testAlertSpecialMutatorsAndStateSupportSingleIdentifierSensors() {
        let muteTill = Date(timeIntervalSince1970: 1_720_000_000)
        for (index, kind) in SingleIdentifierKind.allCases.enumerated() {
            let sensor = makeSingleIdentifierSensor(kind: kind, index: 100 + index)
            let physicalSensor = PhysicalSensorStruct(luid: sensor.luid, macId: sensor.macId)
            let identifier = primaryIdentifier(for: physicalSensor)
            let sut = RuuviServiceAlertImpl(
                cloud: CloudSpy(),
                localIDs: RuuviLocalIDsUserDefaults(),
                ruuviLocalSettings: makeSettings()
            )
            let temperatureAlert = AlertType.temperature(lower: -1, upper: 5)
            let humidityLow = Humidity(value: 2.5, unit: .absolute)
            let humidityHigh = Humidity(value: 6.5, unit: .absolute)
            let updatedHumidityLow = Humidity(value: 3.0, unit: .absolute)
            let updatedHumidityHigh = Humidity(value: 7.5, unit: .absolute)

            sut.register(type: temperatureAlert, ruuviTag: sensor)
            XCTAssertTrue(sut.hasRegistrations(for: physicalSensor))
            XCTAssertEqual(sut.alert(for: physicalSensor, of: temperatureAlert), temperatureAlert)

            sut.mute(type: temperatureAlert, for: physicalSensor, till: muteTill)
            XCTAssertEqual(sut.mutedTill(type: temperatureAlert, for: physicalSensor), muteTill)

            sut.trigger(
                type: temperatureAlert,
                trigerred: true,
                trigerredAt: "2026-04-18T00:00:00Z",
                for: physicalSensor
            )
            XCTAssertEqual(sut.triggered(for: physicalSensor, of: temperatureAlert), true)
            XCTAssertEqual(sut.triggeredAt(for: physicalSensor, of: temperatureAlert), "2026-04-18T00:00:00Z")

            sut.unmute(type: temperatureAlert, for: physicalSensor)
            XCTAssertNil(sut.mutedTill(type: temperatureAlert, for: physicalSensor))

            sut.remove(type: temperatureAlert, ruuviTag: sensor)
            XCTAssertFalse(sut.isOn(type: temperatureAlert, for: physicalSensor))

            sut.register(type: .humidity(lower: humidityLow, upper: humidityHigh), ruuviTag: sensor)
            sut.setLower(humidity: updatedHumidityLow, for: physicalSensor)
            sut.setUpper(humidity: updatedHumidityHigh, for: physicalSensor)
            sut.setHumidity(description: "absolute-\(kind.rawValue)", for: physicalSensor)
            XCTAssertEqual(sut.lowerHumidity(for: physicalSensor)?.value ?? 0, updatedHumidityLow.value, accuracy: 0.0001)
            XCTAssertEqual(sut.upperHumidity(for: physicalSensor)?.value ?? 0, updatedHumidityHigh.value, accuracy: 0.0001)
            XCTAssertEqual(sut.humidityDescription(for: physicalSensor), "absolute-\(kind.rawValue)")
            XCTAssertEqual(sut.lowerHumidity(for: identifier)?.value ?? 0, updatedHumidityLow.value, accuracy: 0.0001)
            XCTAssertEqual(sut.upperHumidity(for: identifier)?.value ?? 0, updatedHumidityHigh.value, accuracy: 0.0001)
            XCTAssertEqual(sut.humidityDescription(for: identifier), "absolute-\(kind.rawValue)")

            sut.register(type: .connection, ruuviTag: sensor)
            sut.setConnection(description: "connection-\(kind.rawValue)", for: physicalSensor)
            XCTAssertEqual(sut.connectionDescription(for: physicalSensor), "connection-\(kind.rawValue)")
            XCTAssertEqual(sut.connectionDescription(for: identifier), "connection-\(kind.rawValue)")

            sut.register(type: .cloudConnection(unseenDuration: 600), ruuviTag: sensor)
            sut.setCloudConnection(unseenDuration: 1200, for: physicalSensor)
            sut.setCloudConnection(description: "offline-\(kind.rawValue)", for: physicalSensor)
            XCTAssertEqual(sut.cloudConnectionUnseenDuration(for: physicalSensor) ?? 0, 1200, accuracy: 0.0001)
            XCTAssertEqual(sut.cloudConnectionDescription(for: physicalSensor), "offline-\(kind.rawValue)")

            sut.register(type: .movement(last: 4), ruuviTag: sensor)
            sut.setMovement(counter: 9, for: physicalSensor)
            sut.setMovement(description: "movement-\(kind.rawValue)", for: physicalSensor)
            XCTAssertEqual(sut.movementCounter(for: physicalSensor), 9)
            XCTAssertEqual(sut.movementDescription(for: physicalSensor), "movement-\(kind.rawValue)")
            XCTAssertEqual(sut.movementCounter(for: identifier), 9)
            XCTAssertEqual(sut.movementDescription(for: identifier), "movement-\(kind.rawValue)")
        }
    }

    func testAlertPhysicalSensorFallsBackToMacWhenLuidHasNoPersistedState() {
        let macOnlySensor = makeSensor(luid: nil, macId: "AA:BB:CC:55:66:77")
        let querySensor = PhysicalSensorStruct(
            luid: "missing-alert-luid".luid,
            macId: macOnlySensor.macId
        )
        let sut = RuuviServiceAlertImpl(
            cloud: CloudSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            ruuviLocalSettings: makeSettings()
        )

        for entry in scalarAlertMutationCases() {
            let description = "fallback-\(entry.name)"
            let alert = entry.makeAlert(entry.initialLower, entry.initialUpper)

            sut.register(type: alert, ruuviTag: macOnlySensor)
            entry.setDescription(sut, description, macOnlySensor)

            XCTAssertEqual(sut.alert(for: querySensor, of: alert), alert)
            XCTAssertEqual(entry.lowerGetter(sut, querySensor) ?? 0, entry.initialLower, accuracy: 0.0001)
            XCTAssertEqual(entry.upperGetter(sut, querySensor) ?? 0, entry.initialUpper, accuracy: 0.0001)
            XCTAssertEqual(entry.descriptionGetter(sut, querySensor), description)

            sut.unregister(type: alert, ruuviTag: macOnlySensor)
        }

        let humidityLow = Humidity(value: 2.5, unit: .absolute)
        let humidityHigh = Humidity(value: 6.5, unit: .absolute)
        sut.register(type: .humidity(lower: humidityLow, upper: humidityHigh), ruuviTag: macOnlySensor)
        sut.setHumidity(description: "fallback-humidity", for: macOnlySensor)
        XCTAssertEqual(sut.lowerHumidity(for: querySensor)?.value ?? 0, humidityLow.value, accuracy: 0.0001)
        XCTAssertEqual(sut.upperHumidity(for: querySensor)?.value ?? 0, humidityHigh.value, accuracy: 0.0001)
        XCTAssertEqual(sut.humidityDescription(for: querySensor), "fallback-humidity")

        sut.register(type: .connection, ruuviTag: macOnlySensor)
        sut.setConnection(description: "fallback-connection", for: macOnlySensor)
        XCTAssertEqual(sut.connectionDescription(for: querySensor), "fallback-connection")

        sut.register(type: .cloudConnection(unseenDuration: 600), ruuviTag: macOnlySensor)
        sut.setCloudConnection(unseenDuration: 900, for: macOnlySensor)
        sut.setCloudConnection(description: "fallback-cloud", for: macOnlySensor)
        XCTAssertEqual(sut.cloudConnectionUnseenDuration(for: querySensor) ?? 0, 900, accuracy: 0.0001)
        XCTAssertEqual(sut.cloudConnectionDescription(for: querySensor), "fallback-cloud")

        sut.register(type: .movement(last: 4), ruuviTag: macOnlySensor)
        sut.setMovement(counter: 11, for: macOnlySensor)
        sut.setMovement(description: "fallback-movement", for: macOnlySensor)
        XCTAssertEqual(sut.movementCounter(for: querySensor), 11)
        XCTAssertEqual(sut.movementDescription(for: querySensor), "fallback-movement")

        let alert = AlertType.temperature(lower: -1, upper: 5)
        let mutedTill = Date(timeIntervalSince1970: 1_730_000_000)
        sut.register(type: alert, ruuviTag: macOnlySensor)
        sut.mute(type: alert, for: macOnlySensor, till: mutedTill)
        sut.trigger(type: alert, trigerred: true, trigerredAt: "2026-04-19T00:00:00Z", for: macOnlySensor)
        XCTAssertEqual(sut.mutedTill(type: alert, for: querySensor), mutedTill)
        XCTAssertEqual(sut.triggered(for: querySensor, of: alert), true)
        XCTAssertEqual(sut.triggeredAt(for: querySensor, of: alert), "2026-04-19T00:00:00Z")
    }

    func testAlertAirQualityGettersReturnNilForSensorWithoutIdentifiers() {
        let noIdentifierSensor = PhysicalSensorStruct(luid: nil, macId: nil)
        let sut = RuuviServiceAlertImpl(
            cloud: CloudSpy(),
            localIDs: RuuviLocalIDsUserDefaults(),
            ruuviLocalSettings: makeSettings()
        )
        let noAssertionGetterNames = Set([
            "aqi",
            "carbonDioxide",
            "pm1",
            "pm25",
            "pm4",
            "pm10",
            "voc",
            "nox",
            "soundInstant",
            "soundAverage",
            "soundPeak",
            "luminosity",
        ])

        for entry in scalarAlertMutationCases() where noAssertionGetterNames.contains(entry.name) {
            XCTAssertNil(entry.lowerGetter(sut, noIdentifierSensor), entry.name)
            XCTAssertNil(entry.upperGetter(sut, noIdentifierSensor), entry.name)
            XCTAssertNil(entry.descriptionGetter(sut, noIdentifierSensor), entry.name)
        }
    }
}

private enum SingleIdentifierKind: String, CaseIterable {
    case luidOnly
    case macOnly
}

private struct AlertQueueCase {
    let expectedType: AlertType
    let cloudType: RuuviCloudAlertType
    let expectedMin: Double?
    let expectedMax: Double?
    let expectedCounter: Int?
    let expectedDelay: Int?
    let expectedDescription: String?
    let registerLocal: (RuuviServiceAlertImpl, RuuviTagSensor, PhysicalSensor) -> Void
    let staleCloudAlert: CloudAlertStub
}

private struct ScalarAlertMutationCase {
    let name: String
    let initialLower: Double
    let initialUpper: Double
    let updatedLower: Double
    let updatedUpper: Double
    let cloudType: RuuviCloudAlertType
    let transform: (Double) -> Double
    let makeAlert: (Double, Double) -> AlertType
    let setLower: (RuuviServiceAlertImpl, Double?, RuuviTagSensor) -> Void
    let setUpper: (RuuviServiceAlertImpl, Double?, RuuviTagSensor) -> Void
    let setDescription: (RuuviServiceAlertImpl, String, RuuviTagSensor) -> Void
    let lowerGetter: (RuuviServiceAlertImpl, PhysicalSensor) -> Double?
    let upperGetter: (RuuviServiceAlertImpl, PhysicalSensor) -> Double?
    let descriptionGetter: (RuuviServiceAlertImpl, PhysicalSensor) -> String?
}

private func formattedMacAddress(index: Int) -> String {
    let suffix = String(format: "%02X", index % 255)
    return "AA:BB:CC:11:22:\(suffix)"
}

private func makeSingleIdentifierSensor(kind: SingleIdentifierKind, index: Int) -> RuuviTagSensor {
    switch kind {
    case .luidOnly:
        return makeSensor(
            luid: "single-luid-\(index)",
            macId: nil
        )
    case .macOnly:
        return makeSensor(
            luid: nil,
            macId: formattedMacAddress(index: 200 + index)
        )
    }
}

private func primaryIdentifier(for sensor: PhysicalSensor) -> String {
    sensor.luid?.value ?? sensor.macId?.value ?? ""
}

private func setAlertUpdatedAt(_ date: Date?, type: AlertType, for sensor: PhysicalSensor) {
    let persistence = AlertPersistenceUserDefaults()
    if let luid = sensor.luid?.value {
        persistence.setUpdatedAt(date, for: luid, of: type)
    }
    if let macId = sensor.macId?.value {
        persistence.setUpdatedAt(date, for: macId, of: type)
    }
}

private func alertQueueCases() -> [AlertQueueCase] {
    let scalarCases = scalarAlertMutationCases().map { entry -> AlertQueueCase in
        let description = "local-\(entry.name)"
        return AlertQueueCase(
            expectedType: entry.makeAlert(entry.initialLower, entry.initialUpper),
            cloudType: entry.cloudType,
            expectedMin: entry.transform(entry.initialLower),
            expectedMax: entry.transform(entry.initialUpper),
            expectedCounter: nil,
            expectedDelay: nil,
            expectedDescription: description,
            registerLocal: { sut, sensor, _ in
                sut.register(
                    type: entry.makeAlert(entry.initialLower, entry.initialUpper),
                    ruuviTag: sensor
                )
                entry.setDescription(sut, description, sensor)
            },
            staleCloudAlert: CloudAlertStub(
                type: entry.cloudType,
                enabled: false,
                min: entry.transform(entry.updatedLower),
                max: entry.transform(entry.updatedUpper),
                counter: nil,
                delay: nil,
                description: "stale-\(entry.name)",
                triggered: nil,
                triggeredAt: nil,
                lastUpdated: Date(timeIntervalSince1970: 1)
            )
        )
    }

    let absoluteHumidityLow = Humidity(value: 2.5, unit: .absolute)
    let absoluteHumidityHigh = Humidity(value: 6.5, unit: .absolute)

    return scalarCases + [
        AlertQueueCase(
            expectedType: .humidity(lower: absoluteHumidityLow, upper: absoluteHumidityHigh),
            cloudType: .humidityAbsolute,
            expectedMin: absoluteHumidityLow.value,
            expectedMax: absoluteHumidityHigh.value,
            expectedCounter: nil,
            expectedDelay: nil,
            expectedDescription: "local-absolute-humidity",
            registerLocal: { sut, sensor, physicalSensor in
                sut.register(
                    type: .humidity(lower: absoluteHumidityLow, upper: absoluteHumidityHigh),
                    ruuviTag: sensor
                )
                sut.setHumidity(description: "local-absolute-humidity", for: physicalSensor)
            },
            staleCloudAlert: CloudAlertStub(
                type: .humidityAbsolute,
                enabled: false,
                min: 1,
                max: 2,
                counter: nil,
                delay: nil,
                description: "stale-absolute-humidity",
                triggered: nil,
                triggeredAt: nil,
                lastUpdated: Date(timeIntervalSince1970: 1)
            )
        ),
        AlertQueueCase(
            expectedType: .cloudConnection(unseenDuration: 1200),
            cloudType: .offline,
            expectedMin: 0,
            expectedMax: 1200,
            expectedCounter: nil,
            expectedDelay: 0,
            expectedDescription: "local-offline",
            registerLocal: { sut, sensor, physicalSensor in
                sut.register(type: .cloudConnection(unseenDuration: 600), ruuviTag: sensor)
                sut.setCloudConnection(unseenDuration: 1200, for: physicalSensor)
                sut.setCloudConnection(description: "local-offline", for: physicalSensor)
            },
            staleCloudAlert: CloudAlertStub(
                type: .offline,
                enabled: false,
                min: 0,
                max: 300,
                counter: nil,
                delay: 0,
                description: "stale-offline",
                triggered: nil,
                triggeredAt: nil,
                lastUpdated: Date(timeIntervalSince1970: 1)
            )
        ),
        AlertQueueCase(
            expectedType: .movement(last: 9),
            cloudType: .movement,
            expectedMin: nil,
            expectedMax: nil,
            expectedCounter: 9,
            expectedDelay: nil,
            expectedDescription: "local-movement",
            registerLocal: { sut, sensor, physicalSensor in
                sut.register(type: .movement(last: 4), ruuviTag: sensor)
                sut.setMovement(counter: 9, for: physicalSensor)
                sut.setMovement(description: "local-movement", for: physicalSensor)
            },
            staleCloudAlert: CloudAlertStub(
                type: .movement,
                enabled: false,
                min: nil,
                max: nil,
                counter: 1,
                delay: nil,
                description: "stale-movement",
                triggered: nil,
                triggeredAt: nil,
                lastUpdated: Date(timeIntervalSince1970: 1)
            )
        ),
    ]
}

private func scalarAlertMutationCases() -> [ScalarAlertMutationCase] {
    [
        .init(name: "temperature", initialLower: -1, initialUpper: 5, updatedLower: -2, updatedUpper: 6, cloudType: .temperature, transform: { $0 }, makeAlert: { .temperature(lower: $0, upper: $1) }, setLower: { $0.setLower(celsius: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(celsius: $1, ruuviTag: $2) }, setDescription: { $0.setTemperature(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerCelsius(for: $1) }, upperGetter: { $0.upperCelsius(for: $1) }, descriptionGetter: { $0.temperatureDescription(for: $1) }),
        .init(name: "relativeHumidity", initialLower: 0.2, initialUpper: 0.7, updatedLower: 0.25, updatedUpper: 0.75, cloudType: .humidity, transform: { $0 * 100.0 }, makeAlert: { .relativeHumidity(lower: $0, upper: $1) }, setLower: { $0.setLower(relativeHumidity: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(relativeHumidity: $1, ruuviTag: $2) }, setDescription: { $0.setRelativeHumidity(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerRelativeHumidity(for: $1) }, upperGetter: { $0.upperRelativeHumidity(for: $1) }, descriptionGetter: { $0.relativeHumidityDescription(for: $1) }),
        .init(name: "dewPoint", initialLower: -5, initialUpper: 1, updatedLower: -4, updatedUpper: 2, cloudType: .dewPoint, transform: { $0 }, makeAlert: { .dewPoint(lower: $0, upper: $1) }, setLower: { $0.setLower(dewPoint: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(dewPoint: $1, ruuviTag: $2) }, setDescription: { $0.setDewPoint(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerDewPoint(for: $1) }, upperGetter: { $0.upperDewPoint(for: $1) }, descriptionGetter: { $0.dewPointDescription(for: $1) }),
        .init(name: "pressure", initialLower: 995, initialUpper: 1005, updatedLower: 996, updatedUpper: 1006, cloudType: .pressure, transform: { $0 * 100.0 }, makeAlert: { .pressure(lower: $0, upper: $1) }, setLower: { $0.setLower(pressure: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(pressure: $1, ruuviTag: $2) }, setDescription: { $0.setPressure(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerPressure(for: $1) }, upperGetter: { $0.upperPressure(for: $1) }, descriptionGetter: { $0.pressureDescription(for: $1) }),
        .init(name: "signal", initialLower: -95, initialUpper: -40, updatedLower: -90, updatedUpper: -35, cloudType: .signal, transform: { $0 }, makeAlert: { .signal(lower: $0, upper: $1) }, setLower: { $0.setLower(signal: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(signal: $1, ruuviTag: $2) }, setDescription: { $0.setSignal(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerSignal(for: $1) }, upperGetter: { $0.upperSignal(for: $1) }, descriptionGetter: { $0.signalDescription(for: $1) }),
        .init(name: "batteryVoltage", initialLower: 2.3, initialUpper: 3.1, updatedLower: 2.4, updatedUpper: 3.2, cloudType: .battery, transform: { $0 }, makeAlert: { .batteryVoltage(lower: $0, upper: $1) }, setLower: { $0.setLower(batteryVoltage: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(batteryVoltage: $1, ruuviTag: $2) }, setDescription: { $0.setBatteryVoltage(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerBatteryVoltage(for: $1) }, upperGetter: { $0.upperBatteryVoltage(for: $1) }, descriptionGetter: { $0.batteryVoltageDescription(for: $1) }),
        .init(name: "aqi", initialLower: 10, initialUpper: 90, updatedLower: 11, updatedUpper: 91, cloudType: .aqi, transform: { $0 }, makeAlert: { .aqi(lower: $0, upper: $1) }, setLower: { $0.setLower(aqi: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(aqi: $1, ruuviTag: $2) }, setDescription: { $0.setAQI(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerAQI(for: $1) }, upperGetter: { $0.upperAQI(for: $1) }, descriptionGetter: { $0.aqiDescription(for: $1) }),
        .init(name: "carbonDioxide", initialLower: 600, initialUpper: 1000, updatedLower: 650, updatedUpper: 1050, cloudType: .co2, transform: { $0 }, makeAlert: { .carbonDioxide(lower: $0, upper: $1) }, setLower: { $0.setLower(carbonDioxide: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(carbonDioxide: $1, ruuviTag: $2) }, setDescription: { $0.setCarbonDioxide(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerCarbonDioxide(for: $1) }, upperGetter: { $0.upperCarbonDioxide(for: $1) }, descriptionGetter: { $0.carbonDioxideDescription(for: $1) }),
        .init(name: "pm1", initialLower: 1, initialUpper: 4, updatedLower: 2, updatedUpper: 5, cloudType: .pm10, transform: { $0 }, makeAlert: { .pMatter1(lower: $0, upper: $1) }, setLower: { $0.setLower(pm1: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(pm1: $1, ruuviTag: $2) }, setDescription: { $0.setPM1(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerPM1(for: $1) }, upperGetter: { $0.upperPM1(for: $1) }, descriptionGetter: { $0.pm1Description(for: $1) }),
        .init(name: "pm25", initialLower: 2, initialUpper: 5, updatedLower: 3, updatedUpper: 6, cloudType: .pm25, transform: { $0 }, makeAlert: { .pMatter25(lower: $0, upper: $1) }, setLower: { $0.setLower(pm25: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(pm25: $1, ruuviTag: $2) }, setDescription: { $0.setPM25(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerPM25(for: $1) }, upperGetter: { $0.upperPM25(for: $1) }, descriptionGetter: { $0.pm25Description(for: $1) }),
        .init(name: "pm4", initialLower: 3, initialUpper: 6, updatedLower: 4, updatedUpper: 7, cloudType: .pm40, transform: { $0 }, makeAlert: { .pMatter4(lower: $0, upper: $1) }, setLower: { $0.setLower(pm4: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(pm4: $1, ruuviTag: $2) }, setDescription: { $0.setPM4(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerPM4(for: $1) }, upperGetter: { $0.upperPM4(for: $1) }, descriptionGetter: { $0.pm4Description(for: $1) }),
        .init(name: "pm10", initialLower: 4, initialUpper: 7, updatedLower: 5, updatedUpper: 8, cloudType: .pm100, transform: { $0 }, makeAlert: { .pMatter10(lower: $0, upper: $1) }, setLower: { $0.setLower(pm10: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(pm10: $1, ruuviTag: $2) }, setDescription: { $0.setPM10(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerPM10(for: $1) }, upperGetter: { $0.upperPM10(for: $1) }, descriptionGetter: { $0.pm10Description(for: $1) }),
        .init(name: "voc", initialLower: 5, initialUpper: 8, updatedLower: 6, updatedUpper: 9, cloudType: .voc, transform: { $0 }, makeAlert: { .voc(lower: $0, upper: $1) }, setLower: { $0.setLower(voc: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(voc: $1, ruuviTag: $2) }, setDescription: { $0.setVOC(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerVOC(for: $1) }, upperGetter: { $0.upperVOC(for: $1) }, descriptionGetter: { $0.vocDescription(for: $1) }),
        .init(name: "nox", initialLower: 6, initialUpper: 9, updatedLower: 7, updatedUpper: 10, cloudType: .nox, transform: { $0 }, makeAlert: { .nox(lower: $0, upper: $1) }, setLower: { $0.setLower(nox: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(nox: $1, ruuviTag: $2) }, setDescription: { $0.setNOX(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerNOX(for: $1) }, upperGetter: { $0.upperNOX(for: $1) }, descriptionGetter: { $0.noxDescription(for: $1) }),
        .init(name: "soundInstant", initialLower: 45, initialUpper: 90, updatedLower: 50, updatedUpper: 95, cloudType: .soundInstant, transform: { $0 }, makeAlert: { .soundInstant(lower: $0, upper: $1) }, setLower: { $0.setLower(soundInstant: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(soundInstant: $1, ruuviTag: $2) }, setDescription: { $0.setSoundInstant(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerSoundInstant(for: $1) }, upperGetter: { $0.upperSoundInstant(for: $1) }, descriptionGetter: { $0.soundInstantDescription(for: $1) }),
        .init(name: "soundAverage", initialLower: 40, initialUpper: 80, updatedLower: 45, updatedUpper: 85, cloudType: .soundAverage, transform: { $0 }, makeAlert: { .soundAverage(lower: $0, upper: $1) }, setLower: { $0.setLower(soundAverage: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(soundAverage: $1, ruuviTag: $2) }, setDescription: { $0.setSoundAverage(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerSoundAverage(for: $1) }, upperGetter: { $0.upperSoundAverage(for: $1) }, descriptionGetter: { $0.soundAverageDescription(for: $1) }),
        .init(name: "soundPeak", initialLower: 60, initialUpper: 110, updatedLower: 65, updatedUpper: 115, cloudType: .soundPeak, transform: { $0 }, makeAlert: { .soundPeak(lower: $0, upper: $1) }, setLower: { $0.setLower(soundPeak: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(soundPeak: $1, ruuviTag: $2) }, setDescription: { $0.setSoundPeak(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerSoundPeak(for: $1) }, upperGetter: { $0.upperSoundPeak(for: $1) }, descriptionGetter: { $0.soundPeakDescription(for: $1) }),
        .init(name: "luminosity", initialLower: 100, initialUpper: 900, updatedLower: 110, updatedUpper: 910, cloudType: .luminosity, transform: { $0 }, makeAlert: { .luminosity(lower: $0, upper: $1) }, setLower: { $0.setLower(luminosity: $1, ruuviTag: $2) }, setUpper: { $0.setUpper(luminosity: $1, ruuviTag: $2) }, setDescription: { $0.setLuminosity(description: $1, ruuviTag: $2) }, lowerGetter: { $0.lowerLuminosity(for: $1) }, upperGetter: { $0.upperLuminosity(for: $1) }, descriptionGetter: { $0.luminosityDescription(for: $1) }),
    ]
}

private func uuidLowerValue(
    for name: String,
    from sut: RuuviServiceAlertImpl,
    uuid: String
) -> Double? {
    switch name {
    case "temperature":
        return sut.lowerCelsius(for: uuid)
    case "relativeHumidity":
        return sut.lowerRelativeHumidity(for: uuid)
    case "dewPoint":
        return sut.lowerDewPoint(for: uuid)
    case "pressure":
        return sut.lowerPressure(for: uuid)
    case "signal":
        return sut.lowerSignal(for: uuid)
    case "batteryVoltage":
        return sut.lowerBatteryVoltage(for: uuid)
    case "aqi":
        return sut.lowerAQI(for: uuid)
    case "carbonDioxide":
        return sut.lowerCarbonDioxide(for: uuid)
    case "pm1":
        return sut.lowerPM1(for: uuid)
    case "pm25":
        return sut.lowerPM25(for: uuid)
    case "pm4":
        return sut.lowerPM4(for: uuid)
    case "pm10":
        return sut.lowerPM10(for: uuid)
    case "voc":
        return sut.lowerVOC(for: uuid)
    case "nox":
        return sut.lowerNOX(for: uuid)
    case "soundInstant":
        return sut.lowerSoundInstant(for: uuid)
    case "soundAverage":
        return sut.lowerSoundAverage(for: uuid)
    case "soundPeak":
        return sut.lowerSoundPeak(for: uuid)
    case "luminosity":
        return sut.lowerLuminosity(for: uuid)
    default:
        return nil
    }
}

private func uuidUpperValue(
    for name: String,
    from sut: RuuviServiceAlertImpl,
    uuid: String
) -> Double? {
    switch name {
    case "temperature":
        return sut.upperCelsius(for: uuid)
    case "relativeHumidity":
        return sut.upperRelativeHumidity(for: uuid)
    case "dewPoint":
        return sut.upperDewPoint(for: uuid)
    case "pressure":
        return sut.upperPressure(for: uuid)
    case "signal":
        return sut.upperSignal(for: uuid)
    case "batteryVoltage":
        return sut.upperBatteryVoltage(for: uuid)
    case "aqi":
        return sut.upperAQI(for: uuid)
    case "carbonDioxide":
        return sut.upperCarbonDioxide(for: uuid)
    case "pm1":
        return sut.upperPM1(for: uuid)
    case "pm25":
        return sut.upperPM25(for: uuid)
    case "pm4":
        return sut.upperPM4(for: uuid)
    case "pm10":
        return sut.upperPM10(for: uuid)
    case "voc":
        return sut.upperVOC(for: uuid)
    case "nox":
        return sut.upperNOX(for: uuid)
    case "soundInstant":
        return sut.upperSoundInstant(for: uuid)
    case "soundAverage":
        return sut.upperSoundAverage(for: uuid)
    case "soundPeak":
        return sut.upperSoundPeak(for: uuid)
    case "luminosity":
        return sut.upperLuminosity(for: uuid)
    default:
        return nil
    }
}

private func uuidDescriptionValue(
    for name: String,
    from sut: RuuviServiceAlertImpl,
    uuid: String
) -> String? {
    switch name {
    case "temperature":
        return sut.temperatureDescription(for: uuid)
    case "relativeHumidity":
        return sut.relativeHumidityDescription(for: uuid)
    case "dewPoint":
        return sut.dewPointDescription(for: uuid)
    case "pressure":
        return sut.pressureDescription(for: uuid)
    case "signal":
        return sut.signalDescription(for: uuid)
    case "batteryVoltage":
        return sut.batteryVoltageDescription(for: uuid)
    case "aqi":
        return sut.aqiDescription(for: uuid)
    case "carbonDioxide":
        return sut.carbonDioxideDescription(for: uuid)
    case "pm1":
        return sut.pm1Description(for: uuid)
    case "pm25":
        return sut.pm25Description(for: uuid)
    case "pm4":
        return sut.pm4Description(for: uuid)
    case "pm10":
        return sut.pm10Description(for: uuid)
    case "voc":
        return sut.vocDescription(for: uuid)
    case "nox":
        return sut.noxDescription(for: uuid)
    case "soundInstant":
        return sut.soundInstantDescription(for: uuid)
    case "soundAverage":
        return sut.soundAverageDescription(for: uuid)
    case "soundPeak":
        return sut.soundPeakDescription(for: uuid)
    case "luminosity":
        return sut.luminosityDescription(for: uuid)
    default:
        return nil
    }
}

private func makeCoverageCloudSyncService(
    storage: StorageSpy = StorageSpy(),
    cloud: CloudSpy = CloudSpy(),
    pool: PoolSpy = PoolSpy(),
    settings: RuuviLocalSettingsUserDefaults,
    syncState: RuuviLocalSyncState = RuuviLocalSyncStateUserDefaults(),
    localImages: RuuviLocalImages = LocalImagesSpy(),
    repository: RepositorySpy = RepositorySpy(),
    localIDs: RuuviLocalIDs = RuuviLocalIDsUserDefaults()
) -> RuuviServiceCloudSyncImpl {
    RuuviServiceCloudSyncImpl(
        ruuviStorage: storage,
        ruuviCloud: cloud,
        ruuviPool: pool,
        ruuviLocalSettings: settings,
        ruuviLocalSyncState: syncState,
        ruuviLocalImages: localImages,
        ruuviRepository: repository,
        ruuviLocalIDs: localIDs,
        ruuviAlertService: RuuviServiceAlertImpl(
            cloud: cloud,
            localIDs: localIDs,
            ruuviLocalSettings: settings
        ),
        ruuviAppSettingsService: RuuviServiceAppSettingsImpl(
            cloud: cloud,
            localSettings: settings
        )
    )
}

private struct CloudSensorSubscriptionCoverageStub: CloudSensorSubscription {
    var macId: String?
    var subscriptionName: String?
    var isActive: Bool?
    var maxClaims: Int?
    var maxHistoryDays: Int?
    var maxResolutionMinutes: Int?
    var maxShares: Int?
    var maxSharesPerSensor: Int?
    var delayedAlertAllowed: Bool?
    var emailAlertAllowed: Bool?
    var offlineAlertAllowed: Bool?
    var pdfExportAllowed: Bool?
    var pushAlertAllowed: Bool?
    var telegramAlertAllowed: Bool?
    var endAt: String?

    init(
        macId: String? = nil,
        subscriptionName: String? = nil,
        isActive: Bool? = true,
        maxClaims: Int? = nil,
        maxHistoryDays: Int? = nil,
        maxResolutionMinutes: Int? = nil,
        maxShares: Int? = nil,
        maxSharesPerSensor: Int? = nil,
        delayedAlertAllowed: Bool? = nil,
        emailAlertAllowed: Bool? = nil,
        offlineAlertAllowed: Bool? = nil,
        pdfExportAllowed: Bool? = nil,
        pushAlertAllowed: Bool? = nil,
        telegramAlertAllowed: Bool? = nil,
        endAt: String? = nil
    ) {
        self.macId = macId
        self.subscriptionName = subscriptionName
        self.isActive = isActive
        self.maxClaims = maxClaims
        self.maxHistoryDays = maxHistoryDays
        self.maxResolutionMinutes = maxResolutionMinutes
        self.maxShares = maxShares
        self.maxSharesPerSensor = maxSharesPerSensor
        self.delayedAlertAllowed = delayedAlertAllowed
        self.emailAlertAllowed = emailAlertAllowed
        self.offlineAlertAllowed = offlineAlertAllowed
        self.pdfExportAllowed = pdfExportAllowed
        self.pushAlertAllowed = pushAlertAllowed
        self.telegramAlertAllowed = telegramAlertAllowed
        self.endAt = endAt
    }
}

private func assertAlertCall(
    _ call: CloudSpy.AlertCall,
    type: RuuviCloudAlertType?,
    settingType: RuuviCloudAlertSettingType,
    isEnabled: Bool,
    min: Double?,
    max: Double?,
    counter: Int?,
    delay: Int?,
    description: String? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(call.type, type, file: file, line: line)
    XCTAssertEqual(call.settingType, settingType, file: file, line: line)
    XCTAssertEqual(call.isEnabled, isEnabled, file: file, line: line)
    if let min {
        XCTAssertEqual(call.min ?? 0, min, accuracy: 0.0001, file: file, line: line)
    } else {
        XCTAssertNil(call.min, file: file, line: line)
    }
    if let max {
        XCTAssertEqual(call.max ?? 0, max, accuracy: 0.0001, file: file, line: line)
    } else {
        XCTAssertNil(call.max, file: file, line: line)
    }
    XCTAssertEqual(call.counter, counter, file: file, line: line)
    XCTAssertEqual(call.delay, delay, file: file, line: line)
    if let description {
        XCTAssertEqual(call.description, description, file: file, line: line)
    }
}

private final class GATTServiceStub: GATTService {
    struct SyncLogsCall {
        let uuid: String
        let mac: String?
        let firmware: Int
        let progressWasProvided: Bool
        let connectionTimeout: TimeInterval?
        let serviceTimeout: TimeInterval?
    }

    var syncLogsCalls: [SyncLogsCall] = []

    func isSyncingLogs(with uuid: String) -> Bool {
        false
    }

    func syncLogs(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?,
        connectionTimeout: TimeInterval?,
        serviceTimeout: TimeInterval?
    ) async throws -> Bool {
        syncLogsCalls.append(
            SyncLogsCall(
                uuid: uuid,
                mac: mac,
                firmware: firmware,
                progressWasProvided: progress != nil,
                connectionTimeout: connectionTimeout,
                serviceTimeout: serviceTimeout
            )
        )
        return true
    }

    func stopGattSync(for uuid: String) async throws -> Bool {
        true
    }
}

private final class DefaultGATTServiceStub: GATTService {
    func isSyncingLogs(with uuid: String) -> Bool {
        false
    }

    func syncLogs(
        uuid: String,
        mac: String?,
        firmware: Int,
        from: Date,
        settings: SensorSettings?,
        progress: ((BTServiceProgress) -> Void)?,
        connectionTimeout: TimeInterval?,
        serviceTimeout: TimeInterval?
    ) async throws -> Bool {
        true
    }
}

private final class OffsetCalibrationStub: RuuviServiceOffsetCalibration {
    struct Call {
        let offset: Double?
        let type: OffsetCorrectionType
        let sensorID: String
        let lastOriginalRecord: RuuviTagSensorRecord?
    }

    var calls: [Call] = []

    func set(
        offset: Double?,
        of type: OffsetCorrectionType,
        for sensor: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        calls.append(
            Call(
                offset: offset,
                type: type,
                sensorID: sensor.id,
                lastOriginalRecord: record
            )
        )
        return SensorSettingsStruct(
            luid: sensor.luid,
            macId: sensor.macId,
            temperatureOffset: offset,
            humidityOffset: nil,
            pressureOffset: nil
        )
    }
}

private final class CloudSyncImageURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var responseData: Data?
    private static var capturedURLs: [URL] = []

    static var requestedURLs: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return capturedURLs
    }

    static func reset(with data: Data?) {
        lock.lock()
        responseData = data
        capturedURLs = []
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "cloud-sync-image.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let data: Data? = Self.withLock {
            Self.capturedURLs.append(url)
            return Self.responseData
        }

        guard let data,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/jpeg"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
