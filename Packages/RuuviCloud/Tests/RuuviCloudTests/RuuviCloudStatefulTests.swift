@testable import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviUser
import XCTest

final class RuuviCloudStatefulTests: XCTestCase {
    override func tearDown() {
        RuuviCloudRequestStateObserverManager.shared.stopAllObservers()
        super.tearDown()
    }

    func testCanonicalProxyUsesFullMacForLoadRecords() async throws {
        let api = CloudApiSpy()
        let user = UserStub(apiKey: "api-key")
        let cloud = RuuviCloudPure(api: api, user: user, pool: nil)
        let localIDs = LocalIDsSpy()
        let originalMac = "AA:BB:CC:11:22:33".mac
        let fullMac = "AA:BB:CC:11:22:33:44".mac
        localIDs.fullMacByMac[originalMac.value] = fullMac
        let sut = RuuviCloudCanonicalProxy(cloud: cloud, localIDs: localIDs)

        _ = try await sut.loadRecords(
            macId: originalMac,
            since: Date(timeIntervalSince1970: 100),
            until: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(api.getSensorDataRequests.map(\.sensor), [fullMac.value])
    }

    func testCanonicalProxyRestoresOriginalMacOnUpdate() async throws {
        let api = CloudApiSpy()
        let user = UserStub(apiKey: "api-key")
        let cloud = RuuviCloudPure(api: api, user: user, pool: nil)
        let localIDs = LocalIDsSpy()
        let originalMac = "AA:BB:CC:11:22:33".mac
        let fullMac = "AA:BB:CC:11:22:33:44".mac
        localIDs.fullMacByMac[originalMac.value] = fullMac
        localIDs.originalMacByFullMac[fullMac.value] = originalMac
        let sut = RuuviCloudCanonicalProxy(cloud: cloud, localIDs: localIDs)
        let sensor = makeSensor(macId: originalMac.value)

        let updated = try await sut.update(name: "Renamed", for: sensor)

        XCTAssertEqual(api.updateRequests.last?.sensor, fullMac.value)
        XCTAssertEqual(updated.macId?.value, originalMac.value)
        XCTAssertEqual(updated.name, "Renamed")
    }

    func testCanonicalProxyRestoresOriginalMacInUploadProgress() async throws {
        let api = CloudApiSpy()
        let user = UserStub(apiKey: "api-key")
        let cloud = RuuviCloudPure(api: api, user: user, pool: nil)
        let localIDs = LocalIDsSpy()
        let originalMac = "AA:BB:CC:11:22:33".mac
        let fullMac = "AA:BB:CC:11:22:33:44".mac
        localIDs.fullMacByMac[originalMac.value] = fullMac
        localIDs.originalMacByFullMac[fullMac.value] = originalMac
        let sut = RuuviCloudCanonicalProxy(cloud: cloud, localIDs: localIDs)
        var progressUpdates: [(String, Double)] = []

        let url = try await sut.upload(
            imageData: Data([0x01, 0x02]),
            mimeType: .png,
            progress: { mac, progress in
                progressUpdates.append((mac.value, progress))
            },
            for: originalMac
        )

        XCTAssertEqual(api.uploadImageRequests.last?.request.sensor, fullMac.value)
        XCTAssertEqual(progressUpdates.map(\.0), [originalMac.value])
        XCTAssertEqual(progressUpdates.count, 1)
        XCTAssertEqual(progressUpdates.first?.1 ?? 0, 0.42, accuracy: 0.0001)
        XCTAssertEqual(url.absoluteString, "https://example.com/image.png")

        let urlWithoutProgress = try await sut.upload(
            imageData: Data([0x03]),
            mimeType: .jpg,
            progress: nil,
            for: originalMac
        )

        XCTAssertEqual(urlWithoutProgress.absoluteString, "https://example.com/image.png")
        XCTAssertEqual(api.uploadImageRequests.count, 2)
    }

    func testCanonicalProxyFallsBackToRequestedMacWhenUploadProgressCannotMapCanonicalMac() async throws {
        let api = CloudApiSpy()
        let cloud = RuuviCloudPure(api: api, user: UserStub(apiKey: "api-key"), pool: nil)
        let localIDs = LocalIDsSpy()
        let originalMac = "AA:BB:CC:11:22:33".mac
        let fullMac = "AA:BB:CC:11:22:33:44".mac
        localIDs.fullMacByMac[originalMac.value] = fullMac
        let sut = RuuviCloudCanonicalProxy(cloud: cloud, localIDs: localIDs)
        var progressMacs: [String] = []

        _ = try await sut.upload(
            imageData: Data([0x01]),
            mimeType: .png,
            progress: { mac, _ in
                progressMacs.append(mac.value)
            },
            for: originalMac
        )

        XCTAssertEqual(api.uploadImageRequests.last?.request.sensor, fullMac.value)
        XCTAssertEqual(progressMacs, [originalMac.value])
    }

    func testCanonicalProxyUsesOriginalFallbackWhenShareResponseOmitsMac() async throws {
        let api = CloudApiSpy()
        let user = UserStub(apiKey: "api-key")
        let cloud = RuuviCloudPure(api: api, user: user, pool: nil)
        let localIDs = LocalIDsSpy()
        let originalMac = "AA:BB:CC:11:22:33".mac
        let fullMac = "AA:BB:CC:11:22:33:44".mac
        localIDs.fullMacByMac[originalMac.value] = fullMac
        let sut = RuuviCloudCanonicalProxy(cloud: cloud, localIDs: localIDs)
        api.shareResponse = RuuviCloudApiShareResponse(sensor: nil, invited: true)

        let response = try await sut.share(macId: originalMac, with: "friend@example.com")

        XCTAssertEqual(api.shareRequests.last?.sensor, fullMac.value)
        XCTAssertEqual(response.macId?.value, originalMac.value)
        XCTAssertEqual(response.invited, true)
    }

    func testCanonicalProxyRestoresReturnedMacForShareAndLoadShared() async throws {
        let api = CloudApiSpy()
        let user = UserStub(apiKey: "api-key")
        let cloud = RuuviCloudPure(api: api, user: user, pool: nil)
        let localIDs = LocalIDsSpy()
        let originalMac = "AA:BB:CC:11:22:33".mac
        let fullMac = "AA:BB:CC:11:22:33:44".mac
        localIDs.set(fullMac: fullMac, for: originalMac)
        api.shareResponse = RuuviCloudApiShareResponse(sensor: fullMac.value, invited: false)
        api.sensorsResponse = RuuviCloudApiGetSensorsResponse(
            sensors: [
                .init(
                    sensor: fullMac.value,
                    name: "Kitchen",
                    picture: "https://example.com/picture.png",
                    isPublic: false,
                    canShare: true,
                    sharedTo: ["friend@example.com"]
                ),
            ]
        )
        let sut = RuuviCloudCanonicalProxy(cloud: cloud, localIDs: localIDs)

        let shared = try await sut.share(macId: originalMac, with: "friend@example.com")
        let loaded = try await sut.loadShared(for: makeSensor(macId: originalMac.value))

        XCTAssertEqual(api.shareRequests.last?.sensor, fullMac.value)
        XCTAssertEqual(shared.macId?.value, originalMac.value)
        XCTAssertEqual(api.sensorsRequests.last?.sensor, fullMac.value)
        XCTAssertEqual(loaded.first?.id, fullMac.value)
    }

    func testCanonicalProxyRestoresOriginalMacFromClaimResponse() async throws {
        let api = CloudApiSpy()
        let user = UserStub(apiKey: "api-key")
        let cloud = RuuviCloudPure(api: api, user: user, pool: nil)
        let localIDs = LocalIDsSpy()
        let originalMac = "AA:BB:CC:11:22:33".mac
        let fullMac = "AA:BB:CC:11:22:33:44".mac
        localIDs.fullMacByMac[originalMac.value] = fullMac
        localIDs.originalMacByFullMac[fullMac.value] = originalMac
        let sut = RuuviCloudCanonicalProxy(cloud: cloud, localIDs: localIDs)
        api.claimResponse = RuuviCloudApiClaimResponse(sensor: fullMac.value)

        let claimedMac = try await sut.claim(name: "Kitchen", macId: originalMac)

        XCTAssertEqual(api.claimRequests.last?.sensor, fullMac.value)
        XCTAssertEqual(claimedMac?.value, originalMac.value)
    }

    func testCanonicalProxyCanonicalizesAdditionalSensorOperations() async throws {
        let api = CloudApiSpy()
        let user = UserStub(apiKey: "api-key")
        let cloud = RuuviCloudPure(api: api, user: user, pool: nil)
        let localIDs = LocalIDsSpy()
        let originalMac = "AA:BB:CC:11:22:33".mac
        let fullMac = "AA:BB:CC:11:22:33:44".mac
        localIDs.set(fullMac: fullMac, for: originalMac)
        let sut = RuuviCloudCanonicalProxy(cloud: cloud, localIDs: localIDs)
        let sensor = makeSensor(macId: originalMac.value)

        _ = try await sut.loadSensorsDense(
            for: sensor,
            measurements: true,
            sharedToOthers: false,
            sharedToMe: true,
            alerts: true,
            settings: true
        )
        let contestedMac = try await sut.contest(macId: originalMac, secret: "secret")
        let unclaimedMac = try await sut.unclaim(macId: originalMac, removeCloudHistory: true)
        let unsharedMac = try await sut.unshare(macId: originalMac, with: "friend@example.com")
        let offsetUpdated = try await sut.update(
            temperatureOffset: 1.5,
            humidityOffset: 2.5,
            pressureOffset: 3.5,
            for: sensor
        )
        let settingsUpdated = try await sut.updateSensorSettings(
            for: sensor,
            types: ["displayOrder"],
            values: ["[\"temperature\"]"],
            timestamp: 123
        )
        try await sut.resetImage(for: originalMac)
        try await sut.setAlert(
            type: .temperature,
            settingType: .state,
            isEnabled: true,
            min: 1.0,
            max: 2.0,
            counter: 3,
            delay: 4,
            description: "alert",
            for: originalMac
        )

        XCTAssertEqual(api.sensorsDenseRequests.last?.sensor, fullMac.value)
        XCTAssertEqual(api.contestRequests.last?.sensor, fullMac.value)
        XCTAssertEqual(contestedMac?.value, originalMac.value)
        XCTAssertEqual(api.unclaimRequests.last?.sensor, fullMac.value)
        XCTAssertEqual(unclaimedMac.value, originalMac.value)
        XCTAssertEqual(api.unshareRequests.last?.sensor, fullMac.value)
        XCTAssertEqual(unsharedMac.value, originalMac.value)
        XCTAssertEqual(api.updateRequests.last?.sensor, fullMac.value)
        XCTAssertEqual(offsetUpdated.macId?.value, originalMac.value)
        XCTAssertEqual(api.postSensorSettingsRequests.last?.sensor, fullMac.value)
        XCTAssertEqual(settingsUpdated.macId?.value, originalMac.value)
        XCTAssertEqual(api.resetImageRequests.last?.sensor, fullMac.value)
        XCTAssertEqual(api.postAlertRequests.last?.sensor, fullMac.value)
    }

    func testCanonicalProxyHandlesNoCanonicalMacAndQueuedRequestPassThrough() async throws {
        let api = CloudApiSpy()
        let cloud = RuuviCloudPure(api: api, user: UserStub(apiKey: "api-key"), pool: nil)
        let sut = RuuviCloudCanonicalProxy(cloud: cloud, localIDs: LocalIDsSpy())
        let sensor = makeSensor(macId: "AA:BB:CC:11:22:33")
        let queued = try makeQueuedRequest(
            type: .settings,
            uniqueKey: "language",
            body: RuuviCloudApiPostSettingRequest(
                name: .profileLanguageCode,
                value: "en",
                timestamp: 1
            )
        )

        let dense = try await sut.loadSensorsDense(
            for: sensor,
            measurements: nil,
            sharedToOthers: nil,
            sharedToMe: nil,
            alerts: nil,
            settings: nil
        )
        let updated = try await sut.update(name: "Renamed", for: sensor)
        let replayed = try await sut.executeQueuedRequest(from: queued)

        XCTAssertEqual(api.sensorsDenseRequests.last?.sensor, sensor.id)
        XCTAssertEqual(dense.count, 0)
        XCTAssertEqual(updated.macId?.value, sensor.id)
        XCTAssertTrue(replayed)
        XCTAssertEqual(api.postSettingRequests.last?.value, "en")
    }

    func testCanonicalProxyLeavesNilMacSensorsUnchanged() async throws {
        let api = CloudApiSpy()
        let cloud = RuuviCloudPure(api: api, user: UserStub(apiKey: "api-key"), pool: nil)
        let sut = RuuviCloudCanonicalProxy(cloud: cloud, localIDs: LocalIDsSpy())
        let sensor = makeSensorWithoutMac()

        let updated = try await sut.update(name: "Renamed", for: sensor)

        XCTAssertEqual(api.updateRequests.last?.sensor, sensor.id)
        XCTAssertNil(updated.macId)
        XCTAssertEqual(updated.name, "Renamed")
    }

    func testCanonicalProxyPassesThroughAccountTokenAndSettingsOperations() async throws {
        let api = CloudApiSpy()
        api.ownerResponse = RuuviCloudAPICheckOwnerResponse(
            email: "owner@example.com",
            sensor: "AA:BB:CC:11:22:33"
        )
        let user = UserStub(apiKey: "api-key")
        let cloud = RuuviCloudPure(api: api, user: user, pool: nil)
        let sut = RuuviCloudCanonicalProxy(cloud: cloud, localIDs: LocalIDsSpy())

        let requestCodeEmail = try await sut.requestCode(email: "owner@example.com")
        let validateResponse = try await sut.validateCode(code: "123456")
        let deleteSucceeded = try await sut.deleteAccount(email: "owner@example.com")
        let tokenID = try await sut.registerPNToken(
            token: "push-token",
            type: "ios",
            name: "phone",
            data: "raw",
            params: ["env": "dev"]
        )
        let unregisterSucceeded = try await sut.unregisterPNToken(token: "push-token", tokenId: nil)
        let tokens = try await sut.listPNTokens()
        let sensors = try await sut.loadSensors()
        let owner = try await sut.checkOwner(macId: "AA:BB:CC:11:22:33".mac)
        let settings = try await sut.getCloudSettings()
        let temperatureUnit = try await sut.set(temperatureUnit: .fahrenheit)
        let temperatureAccuracy = try await sut.set(temperatureAccuracy: .one)
        let humidityUnit = try await sut.set(humidityUnit: .dew)
        let humidityAccuracy = try await sut.set(humidityAccuracy: .zero)
        let pressureUnit = try await sut.set(pressureUnit: .hectopascals)
        let pressureAccuracy = try await sut.set(pressureAccuracy: .two)
        let showAllData = try await sut.set(showAllData: true)
        let drawDots = try await sut.set(drawDots: false)
        let chartDuration = try await sut.set(chartDuration: 72)
        let showMinMaxAvg = try await sut.set(showMinMaxAvg: true)
        let cloudMode = try await sut.set(cloudMode: true)
        let dashboard = try await sut.set(dashboard: true)
        let dashboardType = try await sut.set(dashboardType: .simple)
        let dashboardTapAction = try await sut.set(dashboardTapActionType: .chart)
        let disableEmail = try await sut.set(disableEmailAlert: true)
        let disablePush = try await sut.set(disablePushAlert: false)
        let marketingPreference = try await sut.set(marketingPreference: true)
        let languageCode = try await sut.set(profileLanguageCode: "fi")
        let dashboardOrder = try await sut.set(dashboardSensorOrder: ["b", "a"])
        let alerts = try await sut.loadAlerts()

        XCTAssertEqual(requestCodeEmail, "owner@example.com")
        XCTAssertEqual(validateResponse.email, "owner@example.com")
        XCTAssertTrue(deleteSucceeded)
        XCTAssertEqual(tokenID, 1)
        XCTAssertTrue(unregisterSucceeded)
        XCTAssertEqual(tokens.count, 0)
        XCTAssertEqual(sensors.count, 0)
        XCTAssertEqual(owner.0, "owner@example.com")
        XCTAssertNil(settings)
        XCTAssertEqual(temperatureUnit, .fahrenheit)
        XCTAssertEqual(temperatureAccuracy, .one)
        XCTAssertEqual(humidityUnit, .dew)
        XCTAssertEqual(humidityAccuracy, .zero)
        XCTAssertEqual(pressureUnit, .hectopascals)
        XCTAssertEqual(pressureAccuracy, .two)
        XCTAssertTrue(showAllData)
        XCTAssertFalse(drawDots)
        XCTAssertEqual(chartDuration, 72)
        XCTAssertTrue(showMinMaxAvg)
        XCTAssertTrue(cloudMode)
        XCTAssertTrue(dashboard)
        XCTAssertEqual(dashboardType, .simple)
        XCTAssertEqual(dashboardTapAction, .chart)
        XCTAssertTrue(disableEmail)
        XCTAssertFalse(disablePush)
        XCTAssertTrue(marketingPreference)
        XCTAssertEqual(languageCode, "fi")
        XCTAssertEqual(dashboardOrder, ["b", "a"])
        XCTAssertEqual(alerts.count, 0)

        XCTAssertEqual(api.registerRequests.map(\.email), ["owner@example.com"])
        XCTAssertEqual(api.verifyRequests.map(\.token), ["123456"])
        XCTAssertEqual(api.deleteAccountRequests.map(\.email), ["owner@example.com"])
        XCTAssertEqual(api.registerPNTokenRequests.map(\.token), ["push-token"])
        XCTAssertEqual(api.unregisterPNTokenRequests.map(\.token), ["push-token"])
        XCTAssertEqual(api.listPNTokensRequests.count, 1)
        XCTAssertEqual(api.userRequestsCount, 1)
        XCTAssertEqual(api.ownerRequests.map(\.sensor), ["AA:BB:CC:11:22:33"])
        XCTAssertEqual(api.getSettingsRequests.count, 1)
        XCTAssertEqual(api.getAlertsRequests.count, 1)
        XCTAssertEqual(
            api.postSettingRequests.map(\.name),
            [
                .unitTemperature,
                .accuracyTemperature,
                .unitHumidity,
                .accuracyHumidity,
                .unitPressure,
                .accuracyPressure,
                .chartShowAllPoints,
                .chartDrawDots,
                .chartViewPeriod,
                .chartShowMinMaxAverage,
                .cloudModeEnabled,
                .dashboardEnabled,
                .dashboardType,
                .dashboardTapActionType,
                .emailAlertDisabled,
                .pushAlertDisabled,
                .marketingPreference,
                .profileLanguageCode,
                .dashboardSensorOrder
            ]
        )
    }

    func testPureUpdateNameQueuesFailedRequestAndPublishesStateSequence() async {
        let api = CloudApiSpy()
        api.updateError = RuuviCloudApiError.api(.erInternal)
        let queueExpectation = expectation(description: "queued request saved")
        let statesExpectation = expectation(description: "state notifications")
        statesExpectation.expectedFulfillmentCount = 3
        let pool = PoolSpy()
        pool.onCreateQueuedRequest = { _ in
            queueExpectation.fulfill()
        }
        let user = UserStub(apiKey: "api-key")
        let sut = RuuviCloudPure(api: api, user: user, pool: pool)
        let sensor = makeSensor(macId: "AA:BB:CC:11:22:33")
        var observedStates: [RuuviCloudRequestStateType] = []

        RuuviCloudRequestStateObserverManager.shared.startObserving(for: sensor.id) { state in
            observedStates.append(state)
            statesExpectation.fulfill()
        }

        do {
            _ = try await sut.update(name: "Renamed", for: sensor)
            XCTFail("Expected update to fail")
        } catch let error as RuuviCloudError {
            guard case let .api(apiError) = error,
                  case let .api(code) = apiError else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
            XCTAssertEqual(code, .erInternal)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [queueExpectation, statesExpectation], timeout: 2)
        guard let queuedRequest = pool.createdQueuedRequests.first else {
            return XCTFail("Expected queued request")
        }
        let body = try? XCTUnwrap(queuedRequest.requestBodyData)
        let request = body.flatMap {
            try? JSONDecoder().decode(RuuviCloudApiSensorUpdateRequest.self, from: $0)
        }
        XCTAssertEqual(api.updateRequests.last?.sensor, sensor.id)
        XCTAssertEqual(request?.sensor, sensor.id)
        XCTAssertEqual(request?.name, "Renamed")
        XCTAssertEqual(queuedRequest.type, .sensor)
        XCTAssertEqual(queuedRequest.uniqueKey, "\(sensor.id)-name")
        XCTAssertEqual(observedStates, [.loading, .failed, .complete])
    }

    func testPureSetDashboardSensorOrderPostsJSONStringValue() async throws {
        let api = CloudApiSpy()
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )

        let result = try await sut.set(dashboardSensorOrder: ["sensor-b", "sensor-a"])

        XCTAssertEqual(result, ["sensor-b", "sensor-a"])
        XCTAssertEqual(api.postSettingRequests.last?.name, .dashboardSensorOrder)
        XCTAssertEqual(api.postSettingRequests.last?.value, "[\"sensor-b\",\"sensor-a\"]")
    }

    func testPureUpdateSensorSettingsRejectsMismatchedValues() async {
        let sut = RuuviCloudPure(
            api: CloudApiSpy(),
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )

        do {
            _ = try await sut.updateSensorSettings(
                for: makeSensor(),
                types: ["one", "two"],
                values: ["value"],
                timestamp: 123
            )
            XCTFail("Expected bad parameters error")
        } catch let error as RuuviCloudError {
            guard case let .api(apiError) = error,
                  case .badParameters = apiError else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPureExecuteQueuedUploadImageReplaysStoredRequest() async throws {
        let api = CloudApiSpy()
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )
        let uploadRequest = RuuviCloudApiSensorImageUploadRequest(
            sensor: "AA:BB:CC:11:22:33",
            action: .upload,
            mimeType: .jpg
        )
        let queuedRequest = try makeQueuedRequest(
            type: .uploadImage,
            uniqueKey: "upload",
            body: uploadRequest,
            additionalData: Data([0x0A, 0x0B])
        )

        let success = try await sut.executeQueuedRequest(from: queuedRequest)

        XCTAssertTrue(success)
        XCTAssertEqual(api.uploadImageRequests.last?.request.sensor, uploadRequest.sensor)
        XCTAssertEqual(api.uploadImageRequests.last?.request.action, .upload)
        XCTAssertEqual(api.uploadImageRequests.last?.imageData, Data([0x0A, 0x0B]))
    }

    func testPureRequestCodeWrapsUnexpectedErrorsAsNetworkingFailures() async {
        let api = CloudApiSpy()
        api.registerError = DummyError()
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )

        do {
            _ = try await sut.requestCode(email: "user@example.com")
            XCTFail("Expected networking error")
        } catch let error as RuuviCloudError {
            guard case let .api(apiError) = error,
                  case let .networking(underlying) = apiError,
                  underlying is DummyError else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
            XCTAssertNotNil(underlying)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDenseSettingsDecoderParsesJSONStringArraysAndBooleanStrings() throws {
        let json = """
        {
          "sensors": [{
            "sensor": "AA:BB:CC:11:22:33",
            "owner": "Owner@Example.com",
            "name": "Living room",
            "picture": "https://example.com/image.png",
            "public": false,
            "canShare": true,
            "offsetTemperature": 1.5,
            "offsetHumidity": 12.0,
            "offsetPressure": 250.0,
            "sharedTo": ["shared@example.com"],
            "measurements": [],
            "alerts": [],
            "settings": {
              "displayOrder": "[\\"temperature\\",\\"humidity\\"]",
              "defaultDisplayOrder": "true",
              "displayOrder_lastUpdated": 1700000000,
              "defaultDisplayOrder_lastUpdated": 1700000010,
              "description": "Kitchen sensor",
              "description_lastUpdated": 1700000020
            },
            "subscription": {
              "macId": "AA:BB:CC:11:22:33"
            },
            "lastUpdated": 1700000030
          }]
        }
        """

        let response = try JSONDecoder().decode(
            RuuviCloudApiGetSensorsDenseResponse.self,
            from: Data(json.utf8)
        )

        let sensor = try XCTUnwrap(response.sensors?.first)
        let settings = try XCTUnwrap(sensor.settings)
        XCTAssertEqual(settings.displayOrderCodes, ["temperature", "humidity"])
        XCTAssertEqual(settings.defaultDisplayOrder, true)
        XCTAssertEqual(settings.description, "Kitchen sensor")
        XCTAssertEqual(settings.displayOrderLastUpdatedDate, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(
            settings.defaultDisplayOrderLastUpdatedDate,
            Date(timeIntervalSince1970: 1_700_000_010)
        )
        XCTAssertEqual(
            settings.descriptionLastUpdatedDate,
            Date(timeIntervalSince1970: 1_700_000_020)
        )
        XCTAssertEqual(sensor.lastUpdatedDate, Date(timeIntervalSince1970: 1_700_000_030))
    }

    func testCloudUserResponseNormalizesCloudSensorComputedProperties() throws {
        let json = """
        {
          "email": "owner@example.com",
          "sensors": [{
            "sensor": "AA:BB:CC:11:22:33",
            "owner": "owner@example.com",
            "picture": "https://example.com/sensor.png",
            "name": "Indoor",
            "public": true,
            "offsetTemperature": 1.25,
            "offsetHumidity": 35.0,
            "offsetPressure": 120.0
          }]
        }
        """

        let response = try JSONDecoder().decode(
            RuuviCloudApiUserResponse.self,
            from: Data(json.utf8)
        )

        let sensor = try XCTUnwrap(response.sensors.first)
        XCTAssertEqual(sensor.id, "AA:BB:CC:11:22:33")
        XCTAssertEqual(sensor.owner, "owner@example.com")
        XCTAssertEqual(sensor.picture?.absoluteString, "https://example.com/sensor.png")
        XCTAssertEqual(sensor.offsetTemperature, 1.25)
        XCTAssertEqual(sensor.offsetHumidity ?? 0, 0.35, accuracy: 0.0001)
        XCTAssertEqual(sensor.offsetPressure ?? 0, 1.2, accuracy: 0.0001)
        XCTAssertEqual(sensor.isCloudSensor, true)
        XCTAssertEqual(sensor.canShare, false)
        XCTAssertEqual(sensor.sharedTo, [])
    }

    func testPureSettingWrappersPostExpectedSettingNames() async throws {
        let api = CloudApiSpy()
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )

        let temperatureUnit = try await sut.set(temperatureUnit: .celsius)
        let temperatureAccuracy = try await sut.set(temperatureAccuracy: .one)
        let humidityUnit = try await sut.set(humidityUnit: .gm3)
        let humidityAccuracy = try await sut.set(humidityAccuracy: .two)
        let pressureUnit = try await sut.set(pressureUnit: .hectopascals)
        let pressureAccuracy = try await sut.set(pressureAccuracy: .zero)
        let showAllData = try await sut.set(showAllData: true)
        let drawDots = try await sut.set(drawDots: false)
        let chartDuration = try await sut.set(chartDuration: 24)
        let showMinMaxAvg = try await sut.set(showMinMaxAvg: true)
        let cloudMode = try await sut.set(cloudMode: false)
        let dashboard = try await sut.set(dashboard: true)
        let dashboardType = try await sut.set(dashboardType: .image)
        let dashboardTapActionType = try await sut.set(dashboardTapActionType: .card)
        let disableEmailAlert = try await sut.set(disableEmailAlert: false)
        let disablePushAlert = try await sut.set(disablePushAlert: true)
        let marketingPreference = try await sut.set(marketingPreference: true)
        let profileLanguageCode = try await sut.set(profileLanguageCode: "sv")
        let dashboardSensorOrder = try await sut.set(dashboardSensorOrder: ["a", "b"])

        XCTAssertEqual(temperatureUnit, .celsius)
        XCTAssertEqual(temperatureAccuracy, .one)
        XCTAssertEqual(humidityUnit, .gm3)
        XCTAssertEqual(humidityAccuracy, .two)
        XCTAssertEqual(pressureUnit, .hectopascals)
        XCTAssertEqual(pressureAccuracy, .zero)
        XCTAssertEqual(showAllData, true)
        XCTAssertEqual(drawDots, false)
        XCTAssertEqual(chartDuration, 24)
        XCTAssertEqual(showMinMaxAvg, true)
        XCTAssertEqual(cloudMode, false)
        XCTAssertEqual(dashboard, true)
        XCTAssertEqual(dashboardType, .image)
        XCTAssertEqual(dashboardTapActionType, .card)
        XCTAssertEqual(disableEmailAlert, false)
        XCTAssertEqual(disablePushAlert, true)
        XCTAssertEqual(marketingPreference, true)
        XCTAssertEqual(profileLanguageCode, "sv")
        XCTAssertEqual(dashboardSensorOrder, ["a", "b"])

        XCTAssertEqual(
            api.postSettingRequests.map(\.name),
            [
                .unitTemperature,
                .accuracyTemperature,
                .unitHumidity,
                .accuracyHumidity,
                .unitPressure,
                .accuracyPressure,
                .chartShowAllPoints,
                .chartDrawDots,
                .chartViewPeriod,
                .chartShowMinMaxAverage,
                .cloudModeEnabled,
                .dashboardEnabled,
                .dashboardType,
                .dashboardTapActionType,
                .emailAlertDisabled,
                .pushAlertDisabled,
                .marketingPreference,
                .profileLanguageCode,
                .dashboardSensorOrder,
            ]
        )
        XCTAssertEqual(api.postSettingRequests.last?.value, "[\"a\",\"b\"]")
    }

    func testPureReturnsEmptyCollectionsForMissingOptionalResponseArrays() async throws {
        let api = CloudApiSpy()
        api.getAlertsResponse = RuuviCloudApiGetAlertsResponse(sensors: nil)
        api.sensorsResponse = RuuviCloudApiGetSensorsResponse(sensors: nil)
        api.sensorsDenseResponse = RuuviCloudApiGetSensorsDenseResponse(sensors: nil)
        api.getSensorDataResponse = RuuviCloudApiGetSensorResponse(
            sensor: "AA:BB:CC:11:22:33",
            total: nil,
            name: nil,
            measurements: nil
        )
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )
        let sensor = makeSensor()

        let alerts = try await sut.loadAlerts()
        let shared = try await sut.loadShared(for: sensor)
        let dense = try await sut.loadSensorsDense(
            for: sensor,
            measurements: nil,
            sharedToOthers: nil,
            sharedToMe: nil,
            alerts: nil,
            settings: nil
        )
        let records = try await sut.loadRecords(
            macId: sensor.id.mac,
            since: Date(timeIntervalSince1970: 1),
            until: nil
        )

        XCTAssertEqual(alerts.count, 0)
        XCTAssertEqual(shared.count, 0)
        XCTAssertEqual(dense.count, 0)
        XCTAssertEqual(records.count, 0)
    }

    func testPureUpdateSensorSettingsUsesCurrentTimestampWhenMissing() async throws {
        let api = CloudApiSpy()
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )
        let before = Int(Date().timeIntervalSince1970)

        _ = try await sut.updateSensorSettings(
            for: makeSensor(),
            types: [RuuviCloudApiSetting.sensorDescription.rawValue],
            values: ["Kitchen"],
            timestamp: nil
        )

        let timestamp = try XCTUnwrap(api.postSensorSettingsRequests.last?.timestamp)
        XCTAssertGreaterThanOrEqual(timestamp, before)
        XCTAssertLessThanOrEqual(timestamp, Int(Date().timeIntervalSince1970))
    }

    func testPureSetAlertSuccessAndNotAuthorizedPathsPublishExpectedStates() async throws {
        let api = CloudApiSpy()
        let user = UserStub(apiKey: "api-key")
        let sut = RuuviCloudPure(api: api, user: user, pool: nil)
        let macId = "AA:BB:CC:11:22:33".mac
        var states: [RuuviCloudRequestStateType] = []
        let successExpectation = expectation(description: "success states observed")
        successExpectation.expectedFulfillmentCount = 3

        RuuviCloudRequestStateObserverManager.shared.startObserving(for: macId.value) { state in
            states.append(state)
            successExpectation.fulfill()
        }

        try await sut.setAlert(
            type: .temperature,
            settingType: .state,
            isEnabled: true,
            min: -5,
            max: 20,
            counter: nil,
            delay: nil,
            description: "Room",
            for: macId
        )

        await fulfillment(of: [successExpectation], timeout: 2)
        XCTAssertEqual(api.postAlertRequests.last?.sensor, macId.value)
        XCTAssertEqual(api.postAlertRequests.last?.type, .temperature)
        XCTAssertEqual(states, [.loading, .success, .complete])

        let failureExpectation = expectation(description: "not authorized state sequence")
        failureExpectation.expectedFulfillmentCount = 2
        states.removeAll()

        RuuviCloudRequestStateObserverManager.shared.startObserving(for: macId.value) { state in
            states.append(state)
            failureExpectation.fulfill()
        }
        user.logout()

        do {
            try await sut.setAlert(
                type: .humidity,
                settingType: .description,
                isEnabled: false,
                min: nil,
                max: nil,
                counter: nil,
                delay: nil,
                description: nil,
                for: macId
            )
            XCTFail("Expected not authorized error")
        } catch let error as RuuviCloudError {
            guard case .notAuthorized = error else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [failureExpectation], timeout: 2)
        XCTAssertEqual(states, [.loading, .failed])
    }

    func testPureSetAlertApiFailureQueuesRequestAndPublishesFailureSequence() async {
        let api = CloudApiSpy()
        api.postAlertError = RuuviCloudApiError.api(.erInternal)
        let pool = PoolSpy()
        let queueExpectation = expectation(description: "alert queued")
        let stateExpectation = expectation(description: "alert failure states observed")
        stateExpectation.expectedFulfillmentCount = 3
        pool.onCreateQueuedRequest = { _ in
            queueExpectation.fulfill()
        }
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: pool
        )
        let macId = "AA:BB:CC:11:22:33".mac
        var states: [RuuviCloudRequestStateType] = []

        RuuviCloudRequestStateObserverManager.shared.startObserving(for: macId.value) { state in
            states.append(state)
            stateExpectation.fulfill()
        }

        do {
            try await sut.setAlert(
                type: .humidity,
                settingType: .delay,
                isEnabled: true,
                min: 1,
                max: 2,
                counter: 3,
                delay: 15,
                description: "Air",
                for: macId
            )
            XCTFail("Expected alert update to fail")
        } catch let error as RuuviCloudError {
            guard case let .api(apiError) = error,
                  case let .api(code) = apiError else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
            XCTAssertEqual(code, .erInternal)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [queueExpectation, stateExpectation], timeout: 2)
        let queuedRequest = try? XCTUnwrap(pool.createdQueuedRequests.first)
        let requestData = queuedRequest?.requestBodyData
        let request = requestData.flatMap {
            try? JSONDecoder().decode(RuuviCloudApiPostAlertRequest.self, from: $0)
        }
        XCTAssertEqual(request?.sensor, macId.value)
        XCTAssertEqual(request?.type, .humidity)
        XCTAssertEqual(queuedRequest?.type, .alert)
        XCTAssertEqual(queuedRequest?.uniqueKey, "\(macId.value)-humidity-delay")
        XCTAssertEqual(states, [.loading, .failed, .complete])
    }

    func testPureSetAlertWrapsCloudAndUnexpectedErrors() async {
        let macId = "AA:BB:CC:11:22:33".mac

        do {
            let api = CloudApiSpy()
            api.postAlertError = RuuviCloudError.notAuthorized
            let sut = RuuviCloudPure(api: api, user: UserStub(apiKey: "api-key"), pool: nil)

            try await sut.setAlert(
                type: .temperature,
                settingType: .state,
                isEnabled: true,
                min: nil,
                max: nil,
                counter: nil,
                delay: nil,
                description: nil,
                for: macId
            )
            XCTFail("Expected cloud error")
        } catch let error as RuuviCloudError {
            guard case .notAuthorized = error else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            let api = CloudApiSpy()
            api.postAlertError = DummyError()
            let sut = RuuviCloudPure(api: api, user: UserStub(apiKey: "api-key"), pool: nil)

            try await sut.setAlert(
                type: .humidity,
                settingType: .state,
                isEnabled: true,
                min: nil,
                max: nil,
                counter: nil,
                delay: nil,
                description: nil,
                for: macId
            )
            XCTFail("Expected networking error")
        } catch let error as RuuviCloudError {
            guard case let .api(apiError) = error,
                  case let .networking(underlying) = apiError,
                  underlying is DummyError else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPureOffsetUpdatesQueueRequestsWithSpecificUniqueKeys() async {
        let api = CloudApiSpy()
        api.updateError = RuuviCloudApiError.api(.erInternal)
        let pool = PoolSpy()
        let queueExpectation = expectation(description: "offset requests queued")
        queueExpectation.expectedFulfillmentCount = 3
        pool.onCreateQueuedRequest = { _ in
            queueExpectation.fulfill()
        }
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: pool
        )
        let sensor = makeSensor()
        let offsetUpdates: [(Double?, Double?, Double?)] = [
            (1.5, nil, nil),
            (nil, 0.2, nil),
            (nil, nil, 3.0),
        ]

        for offsets in offsetUpdates {
            do {
                _ = try await sut.update(
                    temperatureOffset: offsets.0,
                    humidityOffset: offsets.1,
                    pressureOffset: offsets.2,
                    for: sensor
                )
                XCTFail("Expected offset update to fail")
            } catch let error as RuuviCloudError {
                guard case let .api(apiError) = error,
                      case let .api(code) = apiError else {
                    return XCTFail("Unexpected cloud error: \(error)")
                }
                XCTAssertEqual(code, .erInternal)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        await fulfillment(of: [queueExpectation], timeout: 2)
        XCTAssertEqual(
            Set(pool.createdQueuedRequests.compactMap(\.uniqueKey)),
            Set([
                "\(sensor.id)-temperatureOffset",
                "\(sensor.id)-humidityOffset",
                "\(sensor.id)-pressureOffset",
            ])
        )
    }

    func testPureOffsetUpdateWithoutSpecificOffsetUsesSensorUniqueKey() async {
        let api = CloudApiSpy()
        api.updateError = RuuviCloudApiError.api(.erInternal)
        let pool = PoolSpy()
        let queueExpectation = expectation(description: "offset request queued")
        pool.onCreateQueuedRequest = { _ in queueExpectation.fulfill() }
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: pool
        )
        let sensor = makeSensor()

        do {
            _ = try await sut.update(
                temperatureOffset: nil,
                humidityOffset: nil,
                pressureOffset: nil,
                for: sensor
            )
            XCTFail("Expected update to fail")
        } catch let error as RuuviCloudError {
            guard case let .api(apiError) = error,
                  case let .api(code) = apiError else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
            XCTAssertEqual(code, .erInternal)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        await fulfillment(of: [queueExpectation], timeout: 2)
        XCTAssertEqual(pool.createdQueuedRequests.first?.uniqueKey, sensor.id)
    }

    func testPureFailedOffsetUpdateDoesNotQueueRequestWhenBodyCannotBeEncoded() async {
        let api = CloudApiSpy()
        api.updateError = RuuviCloudApiError.api(.erInternal)
        let pool = PoolSpy()
        pool.onCreateQueuedRequest = { _ in
            XCTFail("A request containing NaN should not be persisted as JSON")
        }
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: pool
        )

        do {
            _ = try await sut.update(
                temperatureOffset: .nan,
                humidityOffset: nil,
                pressureOffset: nil,
                for: makeSensor()
            )
            XCTFail("Expected update to fail")
        } catch let error as RuuviCloudError {
            guard case let .api(apiError) = error,
                  case let .api(code) = apiError else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
            XCTAssertEqual(code, .erInternal)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(pool.createdQueuedRequests.isEmpty)
    }

    func testPureExecuteQueuedRequestReplaysRemainingSupportedRequestTypes() async throws {
        let api = CloudApiSpy()
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )

        let sensorUpdate = try makeQueuedRequest(
            type: .sensor,
            uniqueKey: "sensor",
            body: RuuviCloudApiSensorUpdateRequest(
                sensor: "AA:BB:CC:11:22:33",
                name: "Kitchen",
                offsetTemperature: nil,
                offsetHumidity: nil,
                offsetPressure: nil,
                timestamp: 1
            )
        )
        let unclaim = try makeQueuedRequest(
            type: .unclaim,
            uniqueKey: "unclaim",
            body: RuuviCloudApiUnclaimRequest(sensor: "AA:BB:CC:11:22:33", deleteData: true)
        )
        let unshare = try makeQueuedRequest(
            type: .unshare,
            uniqueKey: "unshare",
            body: RuuviCloudApiShareRequest(user: "friend@example.com", sensor: "AA:BB:CC:11:22:33")
        )
        let alert = try makeQueuedRequest(
            type: .alert,
            uniqueKey: "alert",
            body: RuuviCloudApiPostAlertRequest(
                sensor: "AA:BB:CC:11:22:33",
                enabled: true,
                type: .temperature,
                min: -1,
                max: 10,
                description: "Room",
                counter: nil,
                delay: nil,
                timestamp: 2
            )
        )
        let setting = try makeQueuedRequest(
            type: .settings,
            uniqueKey: "settings",
            body: RuuviCloudApiPostSettingRequest(
                name: .unitTemperature,
                value: "C",
                timestamp: 3
            )
        )
        let sensorSettings = try makeQueuedRequest(
            type: .sensorSettings,
            uniqueKey: "sensor-settings",
            body: RuuviCloudApiPostSensorSettingsRequest(
                sensor: "AA:BB:CC:11:22:33",
                type: ["description"],
                value: ["Kitchen"],
                timestamp: 4
            )
        )

        let sensorUpdateSuccess = try await sut.executeQueuedRequest(from: sensorUpdate)
        let unclaimSuccess = try await sut.executeQueuedRequest(from: unclaim)
        let unshareSuccess = try await sut.executeQueuedRequest(from: unshare)
        let alertSuccess = try await sut.executeQueuedRequest(from: alert)
        let settingSuccess = try await sut.executeQueuedRequest(from: setting)
        let sensorSettingsSuccess = try await sut.executeQueuedRequest(from: sensorSettings)

        XCTAssertTrue(sensorUpdateSuccess)
        XCTAssertTrue(unclaimSuccess)
        XCTAssertTrue(unshareSuccess)
        XCTAssertTrue(alertSuccess)
        XCTAssertTrue(settingSuccess)
        XCTAssertTrue(sensorSettingsSuccess)

        XCTAssertEqual(api.updateRequests.last?.name, "Kitchen")
        XCTAssertEqual(api.unclaimRequests.last?.sensor, "AA:BB:CC:11:22:33")
        XCTAssertEqual(api.unshareRequests.last?.user, "friend@example.com")
        XCTAssertEqual(api.postAlertRequests.last?.type, .temperature)
        XCTAssertEqual(api.postSettingRequests.last?.name, .unitTemperature)
        XCTAssertEqual(api.postSensorSettingsRequests.last?.sensor, "AA:BB:CC:11:22:33")
    }

    func testPureExecuteQueuedRequestRejectsInvalidQueuedPayloads() async throws {
        let sut = RuuviCloudPure(
            api: CloudApiSpy(),
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )
        let validUploadBody = try JSONEncoder().encode(
            RuuviCloudApiSensorImageUploadRequest(
                sensor: "AA:BB:CC:11:22:33",
                action: .upload,
                mimeType: .jpg
            )
        )
        let missingBody = RuuviCloudQueuedRequestStruct(
            id: 1,
            type: .settings,
            status: .failed,
            uniqueKey: "missing-body",
            requestDate: Date(),
            successDate: nil,
            attempts: 1,
            requestBodyData: nil,
            additionalData: nil
        )
        let missingUploadData = RuuviCloudQueuedRequestStruct(
            id: 2,
            type: .uploadImage,
            status: .failed,
            uniqueKey: "missing-data",
            requestDate: Date(),
            successDate: nil,
            attempts: 1,
            requestBodyData: validUploadBody,
            additionalData: nil
        )
        let noOpType = RuuviCloudQueuedRequestStruct(
            id: 3,
            type: RuuviCloudQueuedRequestType.none,
            status: .failed,
            uniqueKey: "none",
            requestDate: Date(),
            successDate: nil,
            attempts: 1,
            requestBodyData: Data("{}".utf8),
            additionalData: nil
        )
        let invalidJSON = RuuviCloudQueuedRequestStruct(
            id: 4,
            type: .settings,
            status: .failed,
            uniqueKey: "invalid-json",
            requestDate: Date(),
            successDate: nil,
            attempts: 1,
            requestBodyData: Data("not-json".utf8),
            additionalData: nil
        )

        for queuedRequest in [missingBody, missingUploadData, noOpType] {
            do {
                _ = try await sut.executeQueuedRequest(from: queuedRequest)
                XCTFail("Expected bad parameters for \(queuedRequest.uniqueKey ?? "")")
            } catch let error as RuuviCloudError {
                guard case let .api(apiError) = error,
                      case .badParameters = apiError else {
                    return XCTFail("Unexpected cloud error: \(error)")
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        do {
            _ = try await sut.executeQueuedRequest(from: invalidJSON)
            XCTFail("Expected parsing error")
        } catch let error as RuuviCloudError {
            guard case let .api(apiError) = error,
                  case .parsing = apiError else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPureAccountAndSensorWrappersReturnApiValues() async throws {
        let api = CloudApiSpy()
        api.registerPNTokenResponse = RuuviCloudPNTokenRegisterResponse(
            id: 7,
            lastAccessed: 123,
            name: "Phone"
        )
        api.listPNTokensResponse = RuuviCloudPNTokenListResponse(
            tokens: [
                .init(id: 7, lastAccessed: 123, name: "Phone"),
            ]
        )
        api.ownerResponse = RuuviCloudAPICheckOwnerResponse(
            email: "owner@example.com",
            sensor: "AA:BB:CC:11:22:33"
        )
        api.getSettingsResponse = try JSONDecoder().decode(
            RuuviCloudApiGetSettingsResponse.self,
            from: """
            { "settings": { "PROFILE_LANGUAGE_CODE": "sv" } }
            """.data(using: .utf8)!
        )
        api.userResponse = RuuviCloudApiUserResponse(
            email: "owner@example.com",
            sensors: [
                RuuviCloudApiSensor(
                    sensorId: "AA:BB:CC:11:22:33",
                    sensorOwner: "owner@example.com",
                    pictureUrl: "https://example.com/picture.png",
                    name: "Kitchen",
                    isPublic: true,
                    isOwner: false,
                    temperatureOffset: 1.5,
                    humidityOffset: 20,
                    pressureOffset: 120
                ),
            ]
        )
        api.sensorsResponse = RuuviCloudApiGetSensorsResponse(
            sensors: [
                .init(
                    sensor: "AA:BB:CC:11:22:33",
                    name: "Kitchen",
                    picture: "https://example.com/picture.png",
                    isPublic: true,
                    canShare: true,
                    sharedTo: ["friend@example.com"]
                ),
            ]
        )
        api.getAlertsResponse = try JSONDecoder().decode(
            RuuviCloudApiGetAlertsResponse.self,
            from: """
            {
              "sensors": [{
                "sensor": "AA:BB:CC:11:22:33",
                "alerts": [{
                  "type": "temperature",
                  "enabled": true,
                  "min": -5,
                  "max": 20,
                  "counter": 1,
                  "delay": 0,
                  "description": "Room",
                  "triggered": false,
                  "triggeredAt": "",
                  "lastUpdated": 1700000000
                }]
              }]
            }
            """.data(using: .utf8)!
        )
        api.sensorsDenseResponse = try JSONDecoder().decode(
            RuuviCloudApiGetSensorsDenseResponse.self,
            from: """
            {
              "sensors": [{
                "sensor": "AA:BB:CC:11:22:33",
                "owner": "Owner@Example.com",
                "name": "Living room",
                "picture": "https://example.com/image.png",
                "public": false,
                "canShare": true,
                "offsetTemperature": 1.5,
                "offsetHumidity": 12.0,
                "offsetPressure": 250.0,
                "sharedTo": ["shared@example.com"],
                "measurements": [],
                "alerts": [],
                "settings": {
                  "displayOrder": "[\\"temperature\\"]",
                  "defaultDisplayOrder": "false",
                  "displayOrder_lastUpdated": 1700000000,
                  "defaultDisplayOrder_lastUpdated": 1700000010,
                  "description": "Kitchen sensor",
                  "description_lastUpdated": 1700000020
                },
                "subscription": {
                  "macId": "AA:BB:CC:11:22:33"
                }
              }]
            }
            """.data(using: .utf8)!
        )
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )
        let sensor = makeSensor()

        let requestedEmail = try await sut.requestCode(email: "owner@example.com")
        let validated = try await sut.validateCode(code: "123456")
        let deleteSucceeded = try await sut.deleteAccount(email: "owner@example.com")
        let registeredTokenId = try await sut.registerPNToken(
            token: "token",
            type: "ios",
            name: "Phone",
            data: "payload",
            params: ["language": "en"]
        )
        let unregisteredToken = try await sut.unregisterPNToken(token: "token", tokenId: 7)
        let listedTokens = try await sut.listPNTokens()
        let loadedSensors = try await sut.loadSensors()
        let sharedSensors = try await sut.loadShared(for: sensor)
        let owner = try await sut.checkOwner(macId: sensor.id.mac)
        let settings = try await sut.getCloudSettings()
        let alerts = try await sut.loadAlerts()
        let denseSensor = try await sut.loadSensorsDense(
            for: sensor,
            measurements: false,
            sharedToOthers: true,
            sharedToMe: false,
            alerts: true,
            settings: true
        ).first

        XCTAssertEqual(requestedEmail, "owner@example.com")
        XCTAssertEqual(validated.email, "owner@example.com")
        XCTAssertEqual(validated.apiKey, "access-token")
        XCTAssertTrue(deleteSucceeded)
        XCTAssertEqual(registeredTokenId, 7)
        XCTAssertTrue(unregisteredToken)
        XCTAssertEqual(listedTokens.first?.id, 7)
        XCTAssertEqual(loadedSensors.first?.id, "AA:BB:CC:11:22:33")
        XCTAssertEqual(sharedSensors.first?.id, "AA:BB:CC:11:22:33")
        XCTAssertEqual(owner.0, "owner@example.com")
        XCTAssertEqual(settings?.profileLanguageCode, "sv")
        XCTAssertEqual(alerts.first?.sensor, "AA:BB:CC:11:22:33")
        XCTAssertEqual(denseSensor?.sensor.owner, "owner@example.com")
        XCTAssertEqual(denseSensor?.sensor.name, "Living room")
        XCTAssertEqual(denseSensor?.sensor.sharedTo, ["shared@example.com"])
        try await sut.resetImage(for: sensor.id.mac)
        XCTAssertEqual(api.resetImageRequests.last?.sensor, sensor.id)
    }

    func testPureLoadRecordsDecodesNetworkMeasurementsAndRecursesByChunk() async throws {
        let api = CloudApiSpy()
        api.getSensorDataResponse = RuuviCloudApiGetSensorResponse(
            sensor: "AA:BB:CC:11:22:33",
            total: 1,
            name: "Kitchen",
            measurements: [
                .init(
                    gwmac: "11:22:33:44:55:66",
                    coordinates: nil,
                    rssi: -64,
                    timestamp: 1_700_000_000,
                    data: ruuviV5NetworkPayload
                ),
            ]
        )
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )

        let records = try await sut.loadRecords(
            macId: "AA:BB:CC:11:22:33".mac,
            since: Date(timeIntervalSince1970: 1_600_000_000),
            until: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(api.getSensorDataRequests.count, 2)
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.first?.macId?.value, "AA:BB:CC:11:22:33")
        XCTAssertEqual(records.first?.rssi, -64)
        XCTAssertEqual(records.first?.source, .ruuviNetwork)
    }

    func testPureLoadRecordsRecursesWhenLatestRecordIsInFutureAndUntilIsMissing() async throws {
        let api = CloudApiSpy()
        api.getSensorDataResponse = RuuviCloudApiGetSensorResponse(
            sensor: "AA:BB:CC:11:22:33",
            total: 1,
            name: "Kitchen",
            measurements: [
                .init(
                    gwmac: "11:22:33:44:55:66",
                    coordinates: nil,
                    rssi: -64,
                    timestamp: Date().addingTimeInterval(3_600).timeIntervalSince1970,
                    data: ruuviV5NetworkPayload
                ),
            ]
        )
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )

        let records = try await sut.loadRecords(
            macId: "AA:BB:CC:11:22:33".mac,
            since: Date(timeIntervalSince1970: 1_600_000_000),
            until: nil
        )

        XCTAssertEqual(api.getSensorDataRequests.count, 2)
        XCTAssertEqual(records.count, 2)
    }

    func testPureLoadRecordsSkipsUndecodableNetworkMeasurements() async throws {
        let api = CloudApiSpy()
        api.getSensorDataResponse = RuuviCloudApiGetSensorResponse(
            sensor: "AA:BB:CC:11:22:33",
            total: 2,
            name: "Kitchen",
            measurements: [
                .init(
                    gwmac: "11:22:33:44:55:66",
                    coordinates: nil,
                    rssi: nil,
                    timestamp: 1_700_000_000,
                    data: ruuviV5NetworkPayload
                ),
                .init(
                    gwmac: "11:22:33:44:55:66",
                    coordinates: nil,
                    rssi: -64,
                    timestamp: 1_700_000_001,
                    data: "not-a-network-payload"
                ),
            ]
        )
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )

        let records = try await sut.loadRecords(
            macId: "AA:BB:CC:11:22:33".mac,
            since: Date(timeIntervalSince1970: 1_600_000_000),
            until: nil
        )

        XCTAssertEqual(records.count, 0)
        XCTAssertEqual(api.getSensorDataRequests.count, 1)
    }

    func testPureLoadSensorsDenseDecodesLastMeasurementRecord() async throws {
        let api = CloudApiSpy()
        api.sensorsDenseResponse = RuuviCloudApiGetSensorsDenseResponse(
            sensors: [
                .init(
                    sensor: "AA:BB:CC:11:22:33",
                    owner: "owner@example.com",
                    name: "Kitchen",
                    picture: "https://example.com/image.png",
                    isPublic: false,
                    canShare: true,
                    offsetTemperature: nil,
                    offsetHumidity: nil,
                    offsetPressure: nil,
                    sharedTo: nil,
                    measurements: [
                        .init(
                            gwmac: "11:22:33:44:55:66",
                            coordinates: nil,
                            rssi: -63,
                            timestamp: 1_700_000_100,
                            data: ruuviV5NetworkPayload
                        ),
                    ],
                    apiAlerts: nil,
                    subscription: nil,
                    settings: nil,
                    lastUpdated: nil
                ),
            ]
        )
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )

        let dense = try await sut.loadSensorsDense(
            for: makeSensor(),
            measurements: true,
            sharedToOthers: nil,
            sharedToMe: nil,
            alerts: nil,
            settings: nil
        )

        let record = try XCTUnwrap(dense.first?.record)
        XCTAssertEqual(record.macId?.value, "AA:BB:CC:11:22:33")
        XCTAssertEqual(record.rssi, -63)
        XCTAssertEqual(record.date.timeIntervalSince1970, 1_700_000_100)
        XCTAssertEqual(dense.first?.sensor.sharedTo, [])
    }

    func testPureValidateCodeFailsWhenResponseIsMissingCredentials() async {
        let api = CloudApiSpy()
        api.verifyResponse = RuuviCloudApiVerifyResponse(
            email: nil,
            accessToken: nil,
            isNewUser: false
        )
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )

        do {
            _ = try await sut.validateCode(code: "123456")
            XCTFail("Expected invalid response error")
        } catch let error as RuuviCloudError {
            guard case let .api(apiError) = error,
                  case let .api(code) = apiError else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
            XCTAssertEqual(code, .erInternal)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPureAuthorizedOperationsFailWithoutApiKey() async {
        let sut = RuuviCloudPure(
            api: CloudApiSpy(),
            user: UserStub(apiKey: nil),
            pool: nil
        )

        do {
            _ = try await sut.loadAlerts()
            XCTFail("Expected not authorized error")
        } catch let error as RuuviCloudError {
            guard case .notAuthorized = error else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPureCloudOperationPreservesRuuviCloudErrors() async {
        let api = CloudApiSpy()
        api.registerError = RuuviCloudError.notAuthorized
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: nil
        )

        do {
            _ = try await sut.requestCode(email: "user@example.com")
            XCTFail("Expected cloud error")
        } catch let error as RuuviCloudError {
            guard case .notAuthorized = error else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPureUpdateNameFailureBranches() async {
        let sensor = makeSensor()

        do {
            let sut = RuuviCloudPure(
                api: CloudApiSpy(),
                user: UserStub(apiKey: nil),
                pool: nil
            )
            _ = try await sut.update(name: "Renamed", for: sensor)
            XCTFail("Expected not authorized error")
        } catch let error as RuuviCloudError {
            guard case .notAuthorized = error else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            let api = CloudApiSpy()
            api.updateError = RuuviCloudError.notAuthorized
            let sut = RuuviCloudPure(api: api, user: UserStub(apiKey: "api-key"), pool: nil)
            _ = try await sut.update(name: "Renamed", for: sensor)
            XCTFail("Expected cloud error")
        } catch let error as RuuviCloudError {
            guard case .notAuthorized = error else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            let api = CloudApiSpy()
            api.updateError = DummyError()
            let sut = RuuviCloudPure(api: api, user: UserStub(apiKey: "api-key"), pool: nil)
            _ = try await sut.update(name: "Renamed", for: sensor)
            XCTFail("Expected networking error")
        } catch let error as RuuviCloudError {
            guard case let .api(apiError) = error,
                  case let .networking(underlying) = apiError,
                  underlying is DummyError else {
                return XCTFail("Unexpected cloud error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPureUnshareQueuesOnlyWhenEmailIsPresent() async {
        let api = CloudApiSpy()
        api.unshareError = RuuviCloudApiError.api(.erInternal)
        let pool = PoolSpy()
        let queueExpectation = expectation(description: "only explicit email queues")
        pool.onCreateQueuedRequest = { _ in
            queueExpectation.fulfill()
        }
        let sut = RuuviCloudPure(
            api: api,
            user: UserStub(apiKey: "api-key"),
            pool: pool
        )
        let macId = "AA:BB:CC:11:22:33".mac

        do {
            _ = try await sut.unshare(macId: macId, with: nil)
            XCTFail("Expected unshare without email to fail")
        } catch {
            XCTAssertEqual(pool.createdQueuedRequests.count, 0)
        }

        do {
            _ = try await sut.unshare(macId: macId, with: "friend@example.com")
            XCTFail("Expected unshare with email to fail")
        } catch {
            await fulfillment(of: [queueExpectation], timeout: 2)
            XCTAssertEqual(pool.createdQueuedRequests.count, 1)
            XCTAssertEqual(
                pool.createdQueuedRequests.first?.uniqueKey,
                "\(macId.value)-unshare-friend@example.com"
            )
        }
    }

    func testFactoryCreatesPureCloudInstance() {
        let cloud = RuuviCloudFactoryPure().create(
            baseUrl: URL(string: "https://example.com")!,
            user: UserStub(apiKey: "api-key"),
            pool: PoolSpy()
        )

        XCTAssertTrue(cloud is RuuviCloudPure)
    }
}

private final class UserStub: RuuviUser {
    var apiKey: String?
    var email: String?
    var isAuthorized: Bool {
        apiKey != nil
    }

    init(apiKey: String?, email: String? = "owner@example.com") {
        self.apiKey = apiKey
        self.email = email
    }

    func login(apiKey: String) {
        self.apiKey = apiKey
    }

    func logout() {
        apiKey = nil
    }
}

private final class LocalIDsSpy: RuuviLocalIDs {
    var macByLuid: [String: MACIdentifier] = [:]
    var luidByMac: [String: LocalIdentifier] = [:]
    var extendedLuidByMac: [String: LocalIdentifier] = [:]
    var fullMacByMac: [String: MACIdentifier] = [:]
    var originalMacByFullMac: [String: MACIdentifier] = [:]

    func mac(for luid: LocalIdentifier) -> MACIdentifier? {
        macByLuid[luid.value]
    }

    func set(mac: MACIdentifier, for luid: LocalIdentifier) {
        macByLuid[luid.value] = mac
    }

    func luid(for mac: MACIdentifier) -> LocalIdentifier? {
        luidByMac[mac.value]
    }

    func extendedLuid(for mac: MACIdentifier) -> LocalIdentifier? {
        extendedLuidByMac[mac.value]
    }

    func set(luid: LocalIdentifier, for mac: MACIdentifier) {
        luidByMac[mac.value] = luid
    }

    func set(extendedLuid: LocalIdentifier, for mac: MACIdentifier) {
        extendedLuidByMac[mac.value] = extendedLuid
    }

    func fullMac(for mac: MACIdentifier) -> MACIdentifier? {
        fullMacByMac[mac.value]
    }

    func originalMac(for fullMac: MACIdentifier) -> MACIdentifier? {
        originalMacByFullMac[fullMac.value]
    }

    func set(fullMac: MACIdentifier, for mac: MACIdentifier) {
        fullMacByMac[mac.value] = fullMac
        originalMacByFullMac[fullMac.value] = mac
    }

    func removeFullMac(for mac: MACIdentifier) {
        if let fullMac = fullMacByMac.removeValue(forKey: mac.value) {
            originalMacByFullMac.removeValue(forKey: fullMac.value)
        }
    }
}

private final class PoolSpy: RuuviPool {
    private let lock = NSLock()
    private var _createdQueuedRequests: [RuuviCloudQueuedRequest] = []
    var createdQueuedRequests: [RuuviCloudQueuedRequest] {
        withLock {
            _createdQueuedRequests
        }
    }
    var onCreateQueuedRequest: ((RuuviCloudQueuedRequest) -> Void)?

    func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool { true }
    func create(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool { true }
    func deleteLast(_ ruuviTagId: String) async throws -> Bool { true }
    func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool { true }
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool { true }
    func cleanupDBSpace() async throws -> Bool { true }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil
        )
    }

    func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil
        )
    }

    func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil,
            description: description,
            descriptionLastUpdated: descriptionLastUpdated
        )
    }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? { nil }

    func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool {
        withLock {
            _createdQueuedRequests.append(request)
        }
        onCreateQueuedRequest?(request)
        return true
    }

    func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool { true }
    func deleteQueuedRequests() async throws -> Bool { true }

    func save(subscription: CloudSensorSubscription) async throws -> CloudSensorSubscription {
        subscription
    }

    func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws -> CloudSensorSubscription? {
        nil
    }

    private func withLock<T>(_ block: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return block()
    }
}

private final class CloudApiSpy: RuuviCloudApi {
    var registerError: Error?
    var updateError: Error?
    var unshareError: Error?
    var unclaimError: Error?
    var postAlertError: Error?
    var postSettingError: Error?
    var postSensorSettingsError: Error?
    var registerResponse = RuuviCloudApiRegisterResponse(email: "owner@example.com")
    var verifyResponse = RuuviCloudApiVerifyResponse(
        email: "owner@example.com",
        accessToken: "access-token",
        isNewUser: false
    )
    var deleteAccountResponse = RuuviCloudApiAccountDeleteResponse(email: "owner@example.com")
    var registerPNTokenResponse = RuuviCloudPNTokenRegisterResponse(id: 1, lastAccessed: nil, name: nil)
    var unregisterPNTokenResponse = RuuviCloudPNTokenUnregisterResponse()
    var listPNTokensResponse = RuuviCloudPNTokenListResponse(tokens: [])
    var claimResponse = RuuviCloudApiClaimResponse(sensor: "AA:BB:CC:11:22:33")
    var contestResponse = RuuviCloudApiContestResponse(sensor: "AA:BB:CC:11:22:33")
    var unclaimResponse = RuuviCloudApiUnclaimResponse()
    var shareResponse = RuuviCloudApiShareResponse(sensor: "AA:BB:CC:11:22:33", invited: false)
    var unshareResponse = RuuviCloudApiUnshareResponse()
    var sensorsResponse = RuuviCloudApiGetSensorsResponse(sensors: [])
    var ownerResponse = RuuviCloudAPICheckOwnerResponse(email: nil, sensor: nil)
    var sensorsDenseResponse = RuuviCloudApiGetSensorsDenseResponse(sensors: [])
    var userResponse = RuuviCloudApiUserResponse(email: "owner@example.com", sensors: [])
    var getSensorDataResponse = RuuviCloudApiGetSensorResponse(
        sensor: "AA:BB:CC:11:22:33",
        total: 0,
        name: "Sensor",
        measurements: []
    )
    var updateResponse = RuuviCloudApiSensorUpdateResponse(name: "Updated")
    var uploadImageResponse = RuuviCloudApiSensorImageUploadResponse(
        uploadURL: URL(string: "https://example.com/image.png")!
    )
    var resetImageResponse = RuuviCloudApiSensorImageResetResponse()
    var getSettingsResponse = RuuviCloudApiGetSettingsResponse(settings: nil)
    var postSettingResponse = RuuviCloudApiPostSettingResponse(action: "ok")
    var postSensorSettingsResponse = RuuviCloudApiPostSensorSettingsResponse(
        result: "ok",
        data: .init(action: "saved")
    )
    var postAlertResponse = RuuviCloudApiPostAlertResponse(action: "ok")
    var getAlertsResponse = RuuviCloudApiGetAlertsResponse(sensors: [])

    var registerRequests: [RuuviCloudApiRegisterRequest] = []
    var verifyRequests: [RuuviCloudApiVerifyRequest] = []
    var deleteAccountRequests: [RuuviCloudApiAccountDeleteRequest] = []
    var registerPNTokenRequests: [RuuviCloudPNTokenRegisterRequest] = []
    var unregisterPNTokenRequests: [RuuviCloudPNTokenUnregisterRequest] = []
    var listPNTokensRequests: [RuuviCloudPNTokenListRequest] = []
    var claimRequests: [RuuviCloudApiClaimRequest] = []
    var contestRequests: [RuuviCloudApiContestRequest] = []
    var shareRequests: [RuuviCloudApiShareRequest] = []
    var unshareRequests: [RuuviCloudApiShareRequest] = []
    var unclaimRequests: [RuuviCloudApiUnclaimRequest] = []
    var sensorsRequests: [RuuviCloudApiGetSensorsRequest] = []
    var ownerRequests: [RuuviCloudApiGetSensorsRequest] = []
    var sensorsDenseRequests: [RuuviCloudApiGetSensorsDenseRequest] = []
    var getSettingsRequests: [RuuviCloudApiGetSettingsRequest] = []
    var getAlertsRequests: [RuuviCloudApiGetAlertsRequest] = []
    var updateRequests: [RuuviCloudApiSensorUpdateRequest] = []
    var postSettingRequests: [RuuviCloudApiPostSettingRequest] = []
    var postSensorSettingsRequests: [RuuviCloudApiPostSensorSettingsRequest] = []
    var postAlertRequests: [RuuviCloudApiPostAlertRequest] = []
    var getSensorDataRequests: [RuuviCloudApiGetSensorRequest] = []
    var uploadImageRequests: [(request: RuuviCloudApiSensorImageUploadRequest, imageData: Data)] = []
    var resetImageRequests: [RuuviCloudApiSensorImageUploadRequest] = []
    var userRequestsCount = 0

    func register(
        _ requestModel: RuuviCloudApiRegisterRequest
    ) async throws -> RuuviCloudApiRegisterResponse {
        registerRequests.append(requestModel)
        if let registerError {
            throw registerError
        }
        return registerResponse
    }

    func verify(
        _ requestModel: RuuviCloudApiVerifyRequest
    ) async throws -> RuuviCloudApiVerifyResponse {
        verifyRequests.append(requestModel)
        return verifyResponse
    }

    func deleteAccount(
        _ requestModel: RuuviCloudApiAccountDeleteRequest,
        authorization: String
    ) async throws -> RuuviCloudApiAccountDeleteResponse {
        deleteAccountRequests.append(requestModel)
        return deleteAccountResponse
    }

    func registerPNToken(
        _ requestModel: RuuviCloudPNTokenRegisterRequest,
        authorization: String
    ) async throws -> RuuviCloudPNTokenRegisterResponse {
        registerPNTokenRequests.append(requestModel)
        return registerPNTokenResponse
    }

    func unregisterPNToken(
        _ requestModel: RuuviCloudPNTokenUnregisterRequest,
        authorization: String?
    ) async throws -> RuuviCloudPNTokenUnregisterResponse {
        unregisterPNTokenRequests.append(requestModel)
        return unregisterPNTokenResponse
    }

    func listPNTokens(
        _ requestModel: RuuviCloudPNTokenListRequest,
        authorization: String
    ) async throws -> RuuviCloudPNTokenListResponse {
        listPNTokensRequests.append(requestModel)
        return listPNTokensResponse
    }

    func claim(
        _ requestModel: RuuviCloudApiClaimRequest,
        authorization: String
    ) async throws -> RuuviCloudApiClaimResponse {
        claimRequests.append(requestModel)
        return claimResponse
    }

    func contest(
        _ requestModel: RuuviCloudApiContestRequest,
        authorization: String
    ) async throws -> RuuviCloudApiContestResponse {
        contestRequests.append(requestModel)
        return contestResponse
    }

    func unclaim(
        _ requestModel: RuuviCloudApiUnclaimRequest,
        authorization: String
    ) async throws -> RuuviCloudApiUnclaimResponse {
        unclaimRequests.append(requestModel)
        if let unclaimError {
            throw unclaimError
        }
        return unclaimResponse
    }

    func share(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) async throws -> RuuviCloudApiShareResponse {
        shareRequests.append(requestModel)
        return shareResponse
    }

    func unshare(
        _ requestModel: RuuviCloudApiShareRequest,
        authorization: String
    ) async throws -> RuuviCloudApiUnshareResponse {
        unshareRequests.append(requestModel)
        if let unshareError {
            throw unshareError
        }
        return unshareResponse
    }

    func sensors(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetSensorsResponse {
        sensorsRequests.append(requestModel)
        return sensorsResponse
    }

    func owner(
        _ requestModel: RuuviCloudApiGetSensorsRequest,
        authorization: String
    ) async throws -> RuuviCloudAPICheckOwnerResponse {
        ownerRequests.append(requestModel)
        return ownerResponse
    }

    func sensorsDense(
        _ requestModel: RuuviCloudApiGetSensorsDenseRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetSensorsDenseResponse {
        sensorsDenseRequests.append(requestModel)
        return sensorsDenseResponse
    }

    func user(
        authorization: String
    ) async throws -> RuuviCloudApiUserResponse {
        userRequestsCount += 1
        return userResponse
    }

    func getSensorData(
        _ requestModel: RuuviCloudApiGetSensorRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetSensorResponse {
        getSensorDataRequests.append(requestModel)
        return getSensorDataResponse
    }

    func update(
        _ requestModel: RuuviCloudApiSensorUpdateRequest,
        authorization: String
    ) async throws -> RuuviCloudApiSensorUpdateResponse {
        updateRequests.append(requestModel)
        if let updateError {
            throw updateError
        }
        return updateResponse
    }

    func uploadImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        imageData: Data,
        authorization: String,
        uploadProgress: ((Double) -> Void)?
    ) async throws -> RuuviCloudApiSensorImageUploadResponse {
        uploadImageRequests.append((requestModel, imageData))
        uploadProgress?(0.42)
        return uploadImageResponse
    }

    func resetImage(
        _ requestModel: RuuviCloudApiSensorImageUploadRequest,
        authorization: String
    ) async throws -> RuuviCloudApiSensorImageResetResponse {
        resetImageRequests.append(requestModel)
        return resetImageResponse
    }

    func getSettings(
        _ requestModel: RuuviCloudApiGetSettingsRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetSettingsResponse {
        getSettingsRequests.append(requestModel)
        return getSettingsResponse
    }

    func postSetting(
        _ requestModel: RuuviCloudApiPostSettingRequest,
        authorization: String
    ) async throws -> RuuviCloudApiPostSettingResponse {
        postSettingRequests.append(requestModel)
        if let postSettingError {
            throw postSettingError
        }
        return postSettingResponse
    }

    func postSensorSettings(
        _ requestModel: RuuviCloudApiPostSensorSettingsRequest,
        authorization: String
    ) async throws -> RuuviCloudApiPostSensorSettingsResponse {
        postSensorSettingsRequests.append(requestModel)
        if let postSensorSettingsError {
            throw postSensorSettingsError
        }
        return postSensorSettingsResponse
    }

    func postAlert(
        _ requestModel: RuuviCloudApiPostAlertRequest,
        authorization: String
    ) async throws -> RuuviCloudApiPostAlertResponse {
        postAlertRequests.append(requestModel)
        if let postAlertError {
            throw postAlertError
        }
        return postAlertResponse
    }

    func getAlerts(
        _ requestModel: RuuviCloudApiGetAlertsRequest,
        authorization: String
    ) async throws -> RuuviCloudApiGetAlertsResponse {
        getAlertsRequests.append(requestModel)
        return getAlertsResponse
    }
}

private struct DummyError: Error {}

private func makeSensor(macId: String = "AA:BB:CC:11:22:33") -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: 5,
        firmwareVersion: "1.0.0",
        luid: "luid-1".luid,
        macId: macId.mac,
        serviceUUID: nil,
        isConnectable: true,
        name: "Sensor",
        isClaimed: true,
        isOwner: true,
        owner: "owner@example.com",
        ownersPlan: "pro",
        isCloudSensor: true,
        canShare: true,
        sharedTo: ["shared@example.com"],
        maxHistoryDays: 365
    )
}

private func makeSensorWithoutMac() -> RuuviTagSensor {
    RuuviTagSensorStruct(
        version: 5,
        firmwareVersion: "1.0.0",
        luid: "luid-only".luid,
        macId: nil,
        serviceUUID: nil,
        isConnectable: true,
        name: "Sensor",
        isClaimed: true,
        isOwner: true,
        owner: "owner@example.com",
        ownersPlan: "pro",
        isCloudSensor: true,
        canShare: true,
        sharedTo: ["shared@example.com"],
        maxHistoryDays: 365
    )
}

private func makeQueuedRequest<Request: Encodable>(
    type: RuuviCloudQueuedRequestType,
    uniqueKey: String,
    body: Request,
    additionalData: Data? = nil
) throws -> RuuviCloudQueuedRequest {
    let bodyData = try JSONEncoder().encode(body)
    return RuuviCloudQueuedRequestStruct(
        id: 1,
        type: type,
        status: .failed,
        uniqueKey: uniqueKey,
        requestDate: Date(),
        successDate: nil,
        attempts: 1,
        requestBodyData: bodyData,
        additionalData: additionalData
    )
}

private let ruuviV5NetworkPayload =
    "0201061BFF99040512FC5394C37C0004FFFC040CAC364200CDCBB8334C884F"
