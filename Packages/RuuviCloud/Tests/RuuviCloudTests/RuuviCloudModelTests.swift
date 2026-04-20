@testable import RuuviCloud
import RuuviOntology
import XCTest

final class RuuviCloudModelTests: XCTestCase {
    func testVisibilityCodesRoundTripVariantsAndParseCaseInsensitively() {
        for code in RuuviCloudSensorVisibilityCode.allCases {
            XCTAssertEqual(RuuviCloudSensorVisibilityCode(variant: code.variant), code)
            XCTAssertEqual(RuuviCloudSensorVisibilityCode.parse(code.rawValue.lowercased()), code)
            XCTAssertEqual(code.variant.cloudVisibilityCode, code)
        }

        XCTAssertNil(
            RuuviCloudSensorVisibilityCode(
                variant: MeasurementDisplayVariant(type: .txPower)
            )
        )
        XCTAssertNil(RuuviCloudSensorVisibilityCode.parse("not-a-code"))
    }

    func testVisibilityCodesUseDefaultUnitsWhenVariantOmitsUnit() {
        XCTAssertEqual(
            RuuviCloudSensorVisibilityCode(variant: MeasurementDisplayVariant(type: .temperature)),
            .temperatureC
        )
        XCTAssertEqual(
            RuuviCloudSensorVisibilityCode(variant: MeasurementDisplayVariant(type: .humidity)),
            .humidityRelative
        )
        XCTAssertEqual(
            RuuviCloudSensorVisibilityCode(variant: MeasurementDisplayVariant(type: .pressure)),
            .pressureHectopascal
        )
    }

    func testSettingsStringConversionsAndDecodedResponseMapToLocalTypes() throws {
        let json = """
        {
          "settings": {
            "UNIT_TEMPERATURE": "F",
            "ACCURACY_TEMPERATURE": "1",
            "UNIT_HUMIDITY": "2",
            "ACCURACY_HUMIDITY": "0",
            "UNIT_PRESSURE": "3",
            "ACCURACY_PRESSURE": "1",
            "CHART_SHOW_ALL_POINTS": "true",
            "CHART_DRAW_DOTS": "false",
            "CHART_VIEW_PERIOD": "14",
            "CHART_SHOW_MIN_MAX_AVG": "1",
            "CLOUD_MODE_ENABLED": "0",
            "DASHBOARD_ENABLED": "1",
            "DASHBOARD_TYPE": "simple",
            "DASHBOARD_TAP_ACTION": "chart",
            "DISABLE_EMAIL_NOTIFICATIONS": "true",
            "DISABLE_PUSH_NOTIFICATIONS": "false",
            "MARKETING_PREFERENCE": "1",
            "PROFILE_LANGUAGE_CODE": "sv",
            "SENSOR_ORDER": "[\\"a\\",\\"b\\"]"
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RuuviCloudApiGetSettingsResponse.self, from: json)
        let settings = try XCTUnwrap(response.settings)

        XCTAssertEqual(TemperatureUnit.celsius.ruuviCloudApiSettingString, "C")
        XCTAssertEqual(HumidityUnit.gm3.ruuviCloudApiSettingString, "1")
        XCTAssertEqual(UnitPressure.inchesOfMercury.ruuviCloudApiSettingString, "3")
        XCTAssertEqual(14.ruuviCloudApiSettingString, "14")
        XCTAssertEqual(true.chartBoolSettingString, "true")
        XCTAssertEqual("K".ruuviCloudApiSettingUnitTemperature, .kelvin)
        XCTAssertEqual("2".ruuviCloudApiSettingUnitHumidity, .dew)
        XCTAssertEqual("0".ruuviCloudApiSettingUnitPressure, .newtonsPerMetersSquared)
        XCTAssertEqual("false".ruuviCloudApiSettingBoolean, false)
        XCTAssertEqual("15".ruuviCloudApiSettingChartViewPeriod, 15)
        XCTAssertEqual("0".ruuviCloudApiSettingsMeasurementAccuracyUnit, .zero)
        XCTAssertEqual("simple".ruuviCloudApiSettingsDashboardType, .simple)
        XCTAssertEqual("chart".ruuviCloudApiSettingsDashboardTapActionType, .chart)

        XCTAssertEqual(settings.unitTemperature, .fahrenheit)
        XCTAssertEqual(settings.accuracyTemperature, .one)
        XCTAssertEqual(settings.unitHumidity, .dew)
        XCTAssertEqual(settings.accuracyHumidity, .zero)
        XCTAssertEqual(settings.unitPressure, .inchesOfMercury)
        XCTAssertEqual(settings.accuracyPressure, .one)
        XCTAssertEqual(settings.chartShowAllPoints, true)
        XCTAssertEqual(settings.chartDrawDots, false)
        XCTAssertEqual(settings.chartViewPeriod, 14)
        XCTAssertEqual(settings.chartShowMinMaxAvg, true)
        XCTAssertEqual(settings.cloudModeEnabled, false)
        XCTAssertEqual(settings.dashboardEnabled, true)
        XCTAssertEqual(settings.dashboardType, .simple)
        XCTAssertEqual(settings.dashboardTapActionType, .chart)
        XCTAssertEqual(settings.emailAlertDisabled, true)
        XCTAssertEqual(settings.pushAlertDisabled, false)
        XCTAssertEqual(settings.marketingPreference, true)
        XCTAssertEqual(settings.profileLanguageCode, "sv")
        XCTAssertEqual(settings.dashboardSensorOrder, "[\"a\",\"b\"]")
    }

    func testSettingsStringConversionsCoverRemainingVariantsAndFallbacks() {
        XCTAssertEqual(TemperatureUnit.fahrenheit.ruuviCloudApiSettingString, "F")
        XCTAssertEqual(TemperatureUnit.kelvin.ruuviCloudApiSettingString, "K")
        XCTAssertEqual(HumidityUnit.percent.ruuviCloudApiSettingString, "0")
        XCTAssertEqual(HumidityUnit.dew.ruuviCloudApiSettingString, "2")
        XCTAssertEqual(UnitPressure.newtonsPerMetersSquared.ruuviCloudApiSettingString, "0")
        XCTAssertEqual(UnitPressure.hectopascals.ruuviCloudApiSettingString, "1")
        XCTAssertEqual(UnitPressure.millimetersOfMercury.ruuviCloudApiSettingString, "2")
        XCTAssertEqual(UnitPressure.kilopascals.ruuviCloudApiSettingString, "")

        XCTAssertEqual("C".ruuviCloudApiSettingUnitTemperature, .celsius)
        XCTAssertEqual("F".ruuviCloudApiSettingUnitTemperature, .fahrenheit)
        XCTAssertNil("unknown".ruuviCloudApiSettingUnitTemperature)

        XCTAssertEqual("0".ruuviCloudApiSettingUnitHumidity, .percent)
        XCTAssertEqual("1".ruuviCloudApiSettingUnitHumidity, .gm3)
        XCTAssertNil("9".ruuviCloudApiSettingUnitHumidity)

        XCTAssertEqual("1".ruuviCloudApiSettingUnitPressure, .hectopascals)
        XCTAssertEqual("2".ruuviCloudApiSettingUnitPressure, .millimetersOfMercury)
        XCTAssertEqual("3".ruuviCloudApiSettingUnitPressure, .inchesOfMercury)
        XCTAssertNil("9".ruuviCloudApiSettingUnitPressure)

        XCTAssertEqual("true".ruuviCloudApiSettingBoolean, true)
        XCTAssertEqual("1".ruuviCloudApiSettingBoolean, true)
        XCTAssertEqual("0".ruuviCloudApiSettingBoolean, false)
        XCTAssertNil("maybe".ruuviCloudApiSettingBoolean)

        XCTAssertEqual("1".ruuviCloudApiSettingsMeasurementAccuracyUnit, .one)
        XCTAssertEqual("2".ruuviCloudApiSettingsMeasurementAccuracyUnit, .two)
        XCTAssertEqual("unexpected".ruuviCloudApiSettingsMeasurementAccuracyUnit, .two)
        XCTAssertEqual("image".ruuviCloudApiSettingsDashboardType, .image)
        XCTAssertEqual("unexpected".ruuviCloudApiSettingsDashboardType, .image)
        XCTAssertEqual("card".ruuviCloudApiSettingsDashboardTapActionType, .card)
        XCTAssertEqual("unexpected".ruuviCloudApiSettingsDashboardTapActionType, .card)
    }

    func testAlertAndTokenResponsesDecodeAndMapToDomainModels() throws {
        let alertsJSON = """
        {
          "sensors": [{
            "sensor": "AA:BB:CC:11:22:33",
            "alerts": [{
              "type": "temperature",
              "enabled": true,
              "min": -5,
              "max": 25,
              "counter": 3,
              "delay": 15,
              "description": "Room",
              "triggered": false,
              "triggeredAt": "2024-01-01T00:00:00Z",
              "lastUpdated": 1700000000
            }]
          }]
        }
        """.data(using: .utf8)!
        let tokensJSON = """
        {
          "tokens": [
            { "id": 7, "lastAccessed": 123.0, "name": "Phone" },
            { "id": 8, "lastAccessed": null, "name": null }
          ]
        }
        """.data(using: .utf8)!
        let emptyTokensJSON = """
        {}
        """.data(using: .utf8)!

        let alerts = try JSONDecoder().decode(RuuviCloudApiGetAlertsResponse.self, from: alertsJSON)
        let sensor = try XCTUnwrap(alerts.sensors?.first)
        let alert = try XCTUnwrap(sensor.alerts?.first)
        let tokens = try JSONDecoder().decode(RuuviCloudPNTokenListResponse.self, from: tokensJSON)
        let emptyTokens = try JSONDecoder().decode(RuuviCloudPNTokenListResponse.self, from: emptyTokensJSON)

        XCTAssertEqual(sensor.sensor, "AA:BB:CC:11:22:33")
        XCTAssertEqual(alert.type, .temperature)
        XCTAssertEqual(alert.enabled, true)
        XCTAssertEqual(alert.min, -5)
        XCTAssertEqual(alert.max, 25)
        XCTAssertEqual(alert.counter, 3)
        XCTAssertEqual(alert.delay, 15)
        XCTAssertEqual(alert.description, "Room")
        XCTAssertEqual(alert.triggered, false)
        XCTAssertEqual(alert.triggeredAt, "2024-01-01T00:00:00Z")
        XCTAssertEqual(alert.lastUpdated?.timeIntervalSince1970, 1_700_000_000)
        XCTAssertEqual(tokens.anyTokens.map(\.id), [7, 8])
        XCTAssertEqual(tokens.anyTokens.first?.name, "Phone")
        XCTAssertEqual(tokens.anyTokens.first?.lastAccessed, 123)
        XCTAssertEqual(emptyTokens.anyTokens.count, 0)
    }

    func testResponseModelsCoverMissingOptionalBranches() throws {
        let alertsJSON = """
        {
          "sensors": [{
            "sensor": "AA:BB:CC:11:22:33",
            "alerts": [{
              "type": "not-supported",
              "enabled": true,
              "min": 1,
              "max": 2,
              "counter": 3,
              "delay": 4,
              "description": "Unknown",
              "triggered": false,
              "triggeredAt": ""
            }]
          }]
        }
        """.data(using: .utf8)!
        let sensorRecordJSON = """
        {
          "gwmac": "11:22:33:44:55:66",
          "coordinates": "1,2",
          "rssi": -70,
          "data": "payload"
        }
        """.data(using: .utf8)!
        let userJSON = """
        {
          "email": "owner@example.com",
          "sensors": [{
            "sensor": "AA:BB:CC:11:22:33",
            "owner": "owner@example.com",
            "picture": "not a url",
            "name": "Kitchen",
            "public": false
          }]
        }
        """.data(using: .utf8)!
        let denseJSON = """
        {
          "sensors": [{
            "sensor": "AA:BB:CC:11:22:33",
            "owner": "owner@example.com",
            "name": "Office",
            "picture": "https://example.com/picture.png",
            "public": false,
            "canShare": true,
            "settings": {
              "description": "No order"
            }
          }]
        }
        """.data(using: .utf8)!

        let alerts = try JSONDecoder().decode(RuuviCloudApiGetAlertsResponse.self, from: alertsJSON)
        let record = try JSONDecoder().decode(UserApiSensorRecord.self, from: sensorRecordJSON)
        let user = try JSONDecoder().decode(RuuviCloudApiUserResponse.self, from: userJSON)
        let dense = try JSONDecoder().decode(RuuviCloudApiGetSensorsDenseResponse.self, from: denseJSON)

        let alert = try XCTUnwrap(alerts.sensors?.first?.alerts?.first)
        XCTAssertNil(alert.type)
        XCTAssertNil(alert.lastUpdated)

        let before = Date().timeIntervalSince1970 - 1
        let decodedDate = record.date.timeIntervalSince1970
        let after = Date().timeIntervalSince1970 + 1
        XCTAssertGreaterThanOrEqual(decodedDate, before)
        XCTAssertLessThanOrEqual(decodedDate, after)

        let sensor = try XCTUnwrap(user.sensors.first)
        XCTAssertNil(sensor.offsetHumidity)
        XCTAssertNil(sensor.offsetPressure)

        let settings = try XCTUnwrap(dense.sensors?.first?.settings)
        XCTAssertNil(settings.displayOrderCodes)
        XCTAssertNil(settings.defaultDisplayOrder)
        XCTAssertNil(settings.displayOrderLastUpdatedDate)
        XCTAssertNil(settings.defaultDisplayOrderLastUpdatedDate)
        XCTAssertNil(settings.descriptionLastUpdatedDate)
    }

    func testUserResponseMapsCloudSensorOffsetsAndMetadata() throws {
        let json = """
        {
          "email": "owner@example.com",
          "sensors": [{
            "sensor": "AA:BB:CC:11:22:33",
            "owner": "owner@example.com",
            "picture": "https://example.com/image.png",
            "name": "Kitchen",
            "public": true,
            "offsetTemperature": 1.5,
            "offsetHumidity": 25,
            "offsetPressure": 250
          }]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RuuviCloudApiUserResponse.self, from: json)
        var sensor = try XCTUnwrap(response.sensors.first)

        XCTAssertEqual(response.email, "owner@example.com")
        XCTAssertEqual(sensor.sensorId, "AA:BB:CC:11:22:33")
        XCTAssertEqual(sensor.owner, "owner@example.com")
        XCTAssertEqual(sensor.picture?.absoluteString, "https://example.com/image.png")
        XCTAssertEqual(sensor.offsetTemperature, 1.5)
        XCTAssertEqual(try XCTUnwrap(sensor.offsetHumidity), 0.25, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(sensor.offsetPressure), 2.5, accuracy: 0.0001)
        XCTAssertEqual(sensor.id, "AA:BB:CC:11:22:33")
        XCTAssertTrue(sensor.isCloudSensor == true)
        XCTAssertFalse(sensor.isClaimed)
        XCTAssertFalse(sensor.canShare)
        XCTAssertEqual(sensor.sharedTo, [])
        XCTAssertNil(sensor.maxHistoryDays)
        XCTAssertNil(sensor.serviceUUID)
        XCTAssertNil(sensor.lastUpdated)
        XCTAssertNil(sensor.ownersPlan)

        sensor.isOwner = true
        XCTAssertTrue(sensor.isClaimed)
    }

    func testAlertAndDenseSettingsResponsesCoverAlternativeDecodingBranches() throws {
        let alertsJSON = """
        {
          "sensors": [{
            "sensor": "AA:BB:CC:11:22:33",
            "alerts": [{
              "type": "humidity",
              "enabled": false,
              "min": 1,
              "max": 2,
              "counter": 3,
              "delay": null,
              "description": "Air",
              "triggered": true,
              "triggeredAt": "2024-01-01T00:00:00Z",
              "lastUpdated": 1700000000.5
            }]
          }]
        }
        """.data(using: .utf8)!
        let denseJSON = """
        {
          "sensors": [{
            "sensor": "AA:BB:CC:11:22:33",
            "owner": "owner@example.com",
            "name": "Office",
            "picture": "https://example.com/picture.png",
            "public": false,
            "canShare": true,
            "measurements": [{
              "gwmac": "11:22:33:44:55:66",
              "coordinates": "1,2",
              "rssi": -65,
              "timestamp": 1700000001,
              "data": "payload"
            }],
            "alerts": [],
            "settings": {
              "displayOrder": ["temperature", "humidity"],
              "defaultDisplayOrder": true,
              "displayOrder_lastUpdated": 1700000002,
              "defaultDisplayOrder_lastUpdated": 1700000003,
              "description": "Office sensor",
              "description_lastUpdated": 1700000004
            },
            "lastUpdated": 1700000005
          }]
        }
        """.data(using: .utf8)!
        let invalidDenseJSON = """
        {
          "sensors": [{
            "sensor": "AA:BB:CC:11:22:33",
            "owner": "owner@example.com",
            "name": "Office",
            "picture": "https://example.com/picture.png",
            "public": false,
            "canShare": true,
            "measurements": [],
            "alerts": [],
            "settings": {
              "displayOrder": "not-json",
              "defaultDisplayOrder": "maybe"
            }
          }]
        }
        """.data(using: .utf8)!

        let alerts = try JSONDecoder().decode(RuuviCloudApiGetAlertsResponse.self, from: alertsJSON)
        let dense = try JSONDecoder().decode(RuuviCloudApiGetSensorsDenseResponse.self, from: denseJSON)
        let invalidDense = try JSONDecoder().decode(
            RuuviCloudApiGetSensorsDenseResponse.self,
            from: invalidDenseJSON
        )

        let alert = try XCTUnwrap(alerts.sensors?.first?.alerts?.first as? RuuviCloudApiGetAlert)
        XCTAssertNil(alert.delay)
        XCTAssertEqual(
            try XCTUnwrap(alert.lastUpdated?.timeIntervalSince1970),
            1_700_000_000.5,
            accuracy: 0.001
        )

        let settings = try XCTUnwrap(dense.sensors?.first?.settings)
        XCTAssertEqual(settings.displayOrderCodes ?? [], ["temperature", "humidity"])
        XCTAssertEqual(settings.defaultDisplayOrder, true)
        XCTAssertEqual(settings.displayOrderLastUpdatedDate?.timeIntervalSince1970, 1_700_000_002)
        XCTAssertEqual(settings.defaultDisplayOrderLastUpdatedDate?.timeIntervalSince1970, 1_700_000_003)
        XCTAssertEqual(settings.descriptionLastUpdatedDate?.timeIntervalSince1970, 1_700_000_004)
        XCTAssertEqual(dense.sensors?.first?.lastMeasurement?.rssi, -65)
        XCTAssertEqual(dense.sensors?.first?.lastUpdatedDate?.timeIntervalSince1970, 1_700_000_005)

        let invalidSettings = try XCTUnwrap(invalidDense.sensors?.first?.settings)
        XCTAssertNil(invalidSettings.displayOrderCodes)
        XCTAssertNil(invalidSettings.defaultDisplayOrder)
    }

    func testDenseResponseDecodesOffsetsSharingAndSubscription() throws {
        let json = """
        {
          "sensors": [{
            "sensor": "AA:BB:CC:11:22:33",
            "owner": "owner@example.com",
            "name": "Office",
            "picture": "https://example.com/picture.png",
            "public": false,
            "canShare": true,
            "offsetTemperature": 1.5,
            "offsetHumidity": 12,
            "offsetPressure": 345,
            "sharedTo": ["friend@example.com"],
            "measurements": [{
              "gwmac": "11:22:33:44:55:66",
              "coordinates": "1,2",
              "rssi": -65,
              "timestamp": 1700000001,
              "data": "payload"
            }],
            "alerts": [],
            "subscription": {
              "macId": "AA:BB:CC:11:22:33",
              "subscriptionName": "Pro",
              "isActive": true,
              "maxClaims": 10,
              "maxHistoryDays": 365,
              "maxResolutionMinutes": 15,
              "maxShares": 50,
              "maxSharesPerSensor": 5,
              "delayedAlertAllowed": true,
              "emailAlertAllowed": true,
              "offlineAlertAllowed": true,
              "pdfExportAllowed": true,
              "pushAlertAllowed": true,
              "telegramAlertAllowed": false,
              "endAt": "2026-12-31"
            }
          }]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RuuviCloudApiGetSensorsDenseResponse.self, from: json)
        let sensor = try XCTUnwrap(response.sensors?.first)
        let subscription = try XCTUnwrap(sensor.subscription)

        XCTAssertEqual(sensor.offsetTemperature, 1.5)
        XCTAssertEqual(sensor.offsetHumidity, 12)
        XCTAssertEqual(sensor.offsetPressure, 345)
        XCTAssertEqual(sensor.sharedTo ?? [], ["friend@example.com"])
        XCTAssertEqual(sensor.lastMeasurement?.gwmac, "11:22:33:44:55:66")
        XCTAssertEqual(sensor.lastMeasurement?.date.timeIntervalSince1970, 1_700_000_001.0)
        XCTAssertEqual(subscription.macId, "AA:BB:CC:11:22:33")
        XCTAssertEqual(subscription.subscriptionName, "Pro")
        XCTAssertEqual(subscription.isActive, Optional(true))
        XCTAssertEqual(subscription.maxClaims, Optional(10))
        XCTAssertEqual(subscription.maxHistoryDays, Optional(365))
        XCTAssertEqual(subscription.maxResolutionMinutes, Optional(15))
        XCTAssertEqual(subscription.maxShares, Optional(50))
        XCTAssertEqual(subscription.maxSharesPerSensor, Optional(5))
        XCTAssertEqual(subscription.delayedAlertAllowed, Optional(true))
        XCTAssertEqual(subscription.emailAlertAllowed, Optional(true))
        XCTAssertEqual(subscription.offlineAlertAllowed, Optional(true))
        XCTAssertEqual(subscription.pdfExportAllowed, Optional(true))
        XCTAssertEqual(subscription.pushAlertAllowed, Optional(true))
        XCTAssertEqual(subscription.telegramAlertAllowed, Optional(false))
        XCTAssertEqual(subscription.endAt, "2026-12-31")
    }

    func testDenseSettingsCodingKeysRoundTripAndAlertsDefaultToEmpty() {
        typealias Keys = RuuviCloudApiGetSensorsDenseResponse.CloudApiSensor
            .CloudApiSensorSettings.CodingKeys

        XCTAssertEqual(Keys(stringValue: Keys.displayOrder.stringValue), .displayOrder)
        XCTAssertEqual(
            Keys(stringValue: Keys.defaultDisplayOrder.stringValue),
            .defaultDisplayOrder
        )
        XCTAssertEqual(
            Keys(stringValue: Keys.displayOrderLastUpdated.stringValue),
            .displayOrderLastUpdated
        )
        XCTAssertEqual(
            Keys(stringValue: Keys.defaultDisplayOrderLastUpdated.stringValue),
            .defaultDisplayOrderLastUpdated
        )
        XCTAssertEqual(Keys(stringValue: Keys.description.stringValue), .description)
        XCTAssertEqual(
            Keys(stringValue: Keys.descriptionLastUpdated.stringValue),
            .descriptionLastUpdated
        )
        XCTAssertNil(Keys(stringValue: "unknown"))
        XCTAssertNil(Keys(intValue: 1))

        let sensor = RuuviCloudApiGetSensorsDenseResponse.CloudApiSensor(
            sensor: "AA:BB:CC:11:22:33",
            owner: "owner@example.com",
            name: "Office",
            picture: "https://example.com/picture.png",
            isPublic: false,
            canShare: true,
            offsetTemperature: nil,
            offsetHumidity: nil,
            offsetPressure: nil,
            sharedTo: nil,
            measurements: nil,
            apiAlerts: nil,
            subscription: nil,
            settings: nil,
            lastUpdated: nil
        )

        XCTAssertEqual(sensor.alerts.sensor, "AA:BB:CC:11:22:33")
        XCTAssertEqual(sensor.alerts.alerts?.count, 0)
    }

    func testShareableSensorResponseDefaultsMissingFlagsAndRecipients() throws {
        let json = """
        {
          "sensors": [{
            "sensor": "AA:BB:CC:11:22:33",
            "name": "Office"
          }]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(RuuviCloudApiGetSensorsResponse.self, from: json)
        let sensor = try XCTUnwrap(response.sensors?.first)

        XCTAssertFalse(sensor.shareableSensor.canShare)
        XCTAssertEqual(sensor.shareableSensor.sharedTo, [])
    }

    func testBaseResponseReturnsDecodedDataEmptyModelsAndApiErrors() throws {
        let successWithData = """
        {
          "result": "success",
          "data": { "sensor": "AA:BB:CC:11:22:33" }
        }
        """.data(using: .utf8)!
        let successWithoutData = """
        { "result": "success", "data": null }
        """.data(using: .utf8)!
        let successWithoutDataForNonEmptyModel = """
        { "result": "success", "data": null }
        """.data(using: .utf8)!
        let errorWithoutCode = """
        { "result": "error", "error": "Failure" }
        """.data(using: .utf8)!
        let errorWithoutCodeAndDescription = """
        { "result": "error" }
        """.data(using: .utf8)!

        let decodedSuccess = try JSONDecoder().decode(
            RuuviCloudApiBaseResponse<RuuviCloudApiClaimResponse>.self,
            from: successWithData
        )
        let decodedEmpty = try JSONDecoder().decode(
            RuuviCloudApiBaseResponse<RuuviCloudApiSensorImageResetResponse>.self,
            from: successWithoutData
        )
        let decodedError = try JSONDecoder().decode(
            RuuviCloudApiBaseResponse<RuuviCloudApiClaimResponse>.self,
            from: errorWithoutCode
        )
        let decodedMissingSuccessData = try JSONDecoder().decode(
            RuuviCloudApiBaseResponse<RuuviCloudPNTokenRegisterResponse>.self,
            from: successWithoutDataForNonEmptyModel
        )
        let decodedMissingErrorCodeAndDescription = try JSONDecoder().decode(
            RuuviCloudApiBaseResponse<RuuviCloudApiClaimResponse>.self,
            from: errorWithoutCodeAndDescription
        )

        switch decodedSuccess.result {
        case let .success(response):
            XCTAssertEqual(response.sensor, "AA:BB:CC:11:22:33")
        case let .failure(error):
            XCTFail("Unexpected error: \(error)")
        }

        switch decodedEmpty.result {
        case .success:
            break
        case let .failure(error):
            XCTFail("Unexpected error: \(error)")
        }

        switch decodedError.result {
        case .success:
            XCTFail("Expected API error")
        case let .failure(error):
            guard case let .api(code) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(code, .erInternal)
        }

        switch decodedMissingSuccessData.result {
        case .success:
            XCTFail("Expected empty response failure")
        case let .failure(error):
            guard case .emptyResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        switch decodedMissingErrorCodeAndDescription.result {
        case .success:
            XCTFail("Expected empty response failure")
        case let .failure(error):
            guard case .emptyResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testHelperRoundTripsArraysAndRejectsInvalidJSON() {
        let json = RuuviCloudApiHelper.jsonStringFromArray(["temperature", "humidity"])
        let decoded = json.flatMap(RuuviCloudApiHelper.jsonArrayFromString)

        XCTAssertEqual(decoded ?? [], ["temperature", "humidity"])
        XCTAssertNil(RuuviCloudApiHelper.jsonArrayFromString("not-json"))
    }
}
