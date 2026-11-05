import Foundation
import Testing
import RuuviOntology
@testable import RuuviCloud
#if SWIFT_PACKAGE
    import RuuviCloudApi
    import RuuviCloudPure
#endif

extension CloudTransportTests {
    @MainActor @Test func accountEndpointsPreserveIdentityAndRejectIncompleteCredentials() async throws {
        let transport = TransportFixture(
            status: 200, body: cloudSuccess(#"{"email":"test@example.com","accessToken":"secret"}"#))
        defer { transport.close() }
        let service = makeCloudService(api: transport.api, user: CloudTestUser(), pool: nil)
        #expect(try await service.requestCode(email: "test@example.com") == "test@example.com")
        try assertCloudRequest(path: "/register", body: ["email": "test@example.com"], authorized: false)
        let verified = try await service.validateCode(code: "a+b&=?")
        #expect(verified.email == "test@example.com")
        #expect(verified.apiKey == "secret")
        try assertCloudRequest(path: "/verify", query: ["token": "a+b&=?"], authorized: false)
        #expect(try await service.deleteAccount(email: "test@example.com"))
        try assertCloudRequest(path: "/request-delete", body: ["email": "test@example.com"])
        #expect(try await service.deleteAccount(email: "different@example.com") == false)
        for payload in [#"{"email":"test@example.com"}"#, #"{"accessToken":"secret"}"#, "{}"] {
            setCloudResponse(payload)
            do {
                _ = try await service.validateCode(code: "code"); Issue.record("Incomplete credentials accepted")
            } catch {
                guard case .api(.api(.erInternal)) = error else { Issue.record("Unexpected error: \(error)"); continue }
            }
        }
    }

    @MainActor @Test func ownershipAndSharingEndpointsPreserveRequestAndResponseValues() async throws {
        let transport = TransportFixture(
            status: 200,
            body: cloudSuccess(#"{"sensor":"AA:BB:CC:DD:EE:FF","email":"owner@example.com","invited":true}"#))
        defer { transport.close() }
        let service = makeCloudService(api: transport.api, user: CloudTestUser(), pool: nil)
        let mac = "AA:BB:CC:DD:EE:FF".mac
        #expect(try await service.claim(name: "Sauna & spa", macId: mac)?.value == mac.value)
        try assertCloudRequest(path: "/claim", body: ["sensor": mac.value, "name": "Sauna & spa"])
        #expect(try await service.contest(macId: mac, secret: "claim-secret")?.value == mac.value)
        try assertCloudRequest(path: "/contest-sensor", body: ["sensor": mac.value, "secret": "claim-secret"])
        let owner = try await service.checkOwner(macId: mac)
        #expect(owner.0 == "owner@example.com" && owner.1 == mac.value)
        try assertCloudRequest(path: "/check", query: ["sensor": mac.value])
        let shared = try await service.share(macId: mac, with: "guest@example.com")
        #expect(shared.macId?.value == mac.value && shared.invited == true)
        try assertCloudRequest(path: "/share", body: ["sensor": mac.value, "user": "guest@example.com"])
        for recipient in [nil, "guest@example.com"] as [String?] {
            #expect(try await service.unshare(macId: mac, with: recipient).value == mac.value)
            let body = try assertCloudRequest(path: "/unshare", body: ["sensor": mac.value])
            #expect(body["user"] as? String == recipient)
        }
        for deleteHistory in [false, true] {
            #expect(try await service.unclaim(macId: mac, removeCloudHistory: deleteHistory).value == mac.value)
            try assertCloudRequest(path: "/unclaim", body: ["sensor": mac.value, "deleteData": deleteHistory])
        }
        setCloudResponse("{}")
        #expect(try await service.claim(name: "Sauna", macId: mac) == nil)
        #expect(try await service.contest(macId: mac, secret: "secret") == nil)
        let emptyOwner = try await service.checkOwner(macId: mac)
        #expect(emptyOwner.0 == nil && emptyOwner.1 == nil)
    }

    @MainActor @Test func pushTokenLifecycleIncludesOptionalFieldsAndAllowsSignedOutUnregistration() async throws {
        let transport = TransportFixture(status: 200, body: cloudSuccess(#"{"id":42}"#))
        defer { transport.close() }
        let user = CloudTestUser()
        let service = makeCloudService(api: transport.api, user: user, pool: nil)
        #expect(
            try await service.registerPNToken(
                token: "token", type: "ios", name: "Phone", data: "extra",
                params: ["language": "fi", "soundFile": "alert.wav"]) == 42)
        try assertCloudRequest(
            path: "/push-register",
            body: [
                "token": "token", "type": "ios", "name": "Phone",
                "data": "extra", "params": ["language": "fi", "soundFile": "alert.wav"],
            ])
        setCloudResponse(#"{"tokens":[{"id":42,"name":"Phone","lastAccessed":1700000000},{"id":43}]}"#)
        let tokens = try await service.listPNTokens()
        #expect(tokens.map(\.id) == [42, 43])
        #expect(tokens.first?.name == "Phone" && tokens.first?.lastAccessed == 1_700_000_000)
        #expect(tokens.last?.name == nil && tokens.last?.lastAccessed == nil)
        try assertCloudRequest(path: "/push-list", query: [:])
        setCloudResponse("{}")
        #expect(try await service.listPNTokens().isEmpty)
        #expect(try await service.unregisterPNToken(token: "token", tokenId: nil))
        try assertCloudRequest(path: "/push-unregister", body: ["token": "token"])
        user.logout()
        #expect(try await service.unregisterPNToken(token: nil, tokenId: 42))
        try assertCloudRequest(path: "/push-unregister", body: ["id": 42], authorized: false)
    }

    @MainActor @Test func sensorEditsPreserveCalibrationAndValidateSettingsBeforeNetworking() async throws {
        let transport = TransportFixture(status: 200, body: cloudSuccess("{}"))
        defer { transport.close() }
        let service = makeCloudService(api: transport.api, user: CloudTestUser(), pool: nil)
        let sensor = cloudTestSensor()
        let renamed = try await service.update(name: "Living room", for: sensor)
        #expect(renamed.name == "Living room" && renamed.id == sensor.id)
        try assertCloudRequest(path: "/update", body: ["sensor": sensor.id, "name": "Living room"])
        let calibrated = try await service.update(
            temperatureOffset: 1.5, humidityOffset: 10, pressureOffset: 200, for: sensor)
        #expect(calibrated.id == sensor.id)
        try assertCloudRequest(
            path: "/update",
            body: [
                "sensor": sensor.id, "name": sensor.name,
                "offsetTemperature": 1.5, "offsetHumidity": 10, "offsetPressure": 200,
            ])
        let configured = try await service.updateSensorSettings(
            for: sensor, types: ["displayOrder", "description"],
            values: ["TEMPERATURE_F", "Indoor"], timestamp: 1234)
        #expect(configured.id == sensor.id)
        try assertCloudRequest(
            path: "/sensor-settings",
            body: [
                "sensor": sensor.id, "type": ["displayOrder", "description"],
                "value": ["TEMPERATURE_F", "Indoor"], "timestamp": 1234,
            ])
        setCloudResponse("{}")
        do {
            _ = try await service.updateSensorSettings(for: sensor, types: ["description"], values: [], timestamp: nil)
            Issue.record("Mismatched setting arrays accepted")
        } catch { guard case .api(.badParameters) = error else { Issue.record("Unexpected error: \(error)"); return } }
        #expect(TransportProtocol.state.requests.isEmpty)
        try await service.resetImage(for: sensor.macId!)
        try assertCloudRequest(path: "/upload", body: ["sensor": sensor.id, "action": "reset"])
    }

    @MainActor @Test func readEndpointsDecodeOwnersSharesAlertsAndAbsentData() async throws {
        let transport = TransportFixture(status: 200, body: cloudSuccess("{}"))
        defer { transport.close() }
        let service = makeCloudService(api: transport.api, user: CloudTestUser(), pool: nil)
        let sensor = cloudTestSensor()
        setCloudResponse(
            #"""
            {
              "email": "test@example.com",
              "sensors": [
                {
                  "sensor": "AA:BB:CC:DD:EE:FF",
                  "owner": "test@example.com",
                  "name": "Sauna",
                  "picture": "https://example.com/image.jpg",
                  "public": false,
                  "offsetTemperature": 1,
                  "offsetHumidity": 10,
                  "offsetPressure": 200
                }
              ]
            }
            """#
        )
        let sensors = try await service.loadSensors()
        let loaded = try #require(sensors.first)
        #expect(loaded.id == sensor.id && loaded.name == "Sauna" && loaded.isOwner)
        #expect(loaded.offsetTemperature == 1 && loaded.offsetHumidity == 0.1 && loaded.offsetPressure == 2)
        #expect(loaded.picture?.absoluteString == "https://example.com/image.jpg")
        try assertCloudRequest(path: "/user", query: [:])
        setCloudResponse(
            #"{"sensors":[{"sensor":"AA:BB:CC:DD:EE:FF","canShare":true,"sharedTo":["guest@example.com"],"sharedToPending":["new@example.com"]}]}"#
        )
        let shares = try await service.loadShared(for: sensor)
        #expect(shares.count == 1)
        #expect(shares.first?.sharedTo == ["guest@example.com"])
        #expect(shares.first?.sharedToPending == ["new@example.com"])
        #expect(shares.first?.canShare == true)
        try assertCloudRequest(path: "/sensors", query: ["sensor": sensor.id])
        setCloudResponse(
            #"""
            {
              "sensors": [
                {
                  "sensor": "AA:BB:CC:DD:EE:FF",
                  "alerts": [
                    {
                      "type": "temperature",
                      "enabled": true,
                      "min": -20,
                      "max": 40,
                      "counter": 0,
                      "delay": 60,
                      "description": "Sauna",
                      "triggered": true,
                      "triggeredAt": "2026-01-01T00:00:00Z",
                      "lastUpdated": 1700000000
                    }
                  ]
                }
              ]
            }
            """#
        )
        let alerts = try await service.loadAlerts()
        let alert = try #require(alerts.first?.alerts?.first)
        #expect(alert.min == -20 && alert.max == 40 && alert.delay == 60)
        #expect(alert.description == "Sauna" && alert.triggered == true)
        #expect(alert.lastUpdated == Date(timeIntervalSince1970: 1_700_000_000))
        try assertCloudRequest(path: "/alerts", query: [:])
        setCloudResponse("{}")
        #expect(try await service.loadAlerts().isEmpty)
        #expect(try await service.loadShared(for: sensor).isEmpty)
        #expect(try await service.getCloudSettings() == nil)
        #expect(
            try await service.loadSensorsDense(
                for: nil, measurements: nil, sharedToOthers: nil, sharedToMe: nil,
                alerts: nil, settings: nil
            ).isEmpty)
    }
}

func cloudSuccess(_ payload: String) -> String { "{\"result\":\"success\",\"data\":\(payload)}" }
func setCloudResponse(_ payload: String) {
    TransportProtocol.state.configure(status: 200, data: Data(cloudSuccess(payload).utf8), error: nil, pending: false)
}

@discardableResult func assertCloudRequest(
    path: String, body expectedBody: [String: Any]? = nil,
    query expectedQuery: [String: String]? = nil,
    authorized: Bool = true
) throws -> [String: Any] {
    let request = try #require(TransportProtocol.state.request)
    #expect(request.url?.path == path)
    #expect(request.httpMethod == (expectedQuery == nil ? "POST" : "GET"))
    #expect(request.value(forHTTPHeaderField: "Authorization") == (authorized ? "test-key" : nil))
    if let expectedQuery {
        let parts = try #require(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        let query = Dictionary(
            (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { _, last in last })
        for (key, value) in expectedQuery { #expect(query[key] == value) }
        #expect(TransportProtocol.state.body == nil)
        return [:]
    }
    let data = try #require(TransportProtocol.state.body)
    let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    for (key, value) in expectedBody ?? [:] {
        #expect(NSDictionary(dictionary: [key: body[key] as Any]).isEqual(to: [key: value]))
    }
    return body
}

func cloudTestSensor() -> RuuviTagSensorStruct {
    RuuviTagSensorStruct(
        version: 5, firmwareVersion: nil, luid: nil, macId: "AA:BB:CC:DD:EE:FF".mac,
        serviceUUID: nil, isConnectable: false, name: "Sauna", isClaimed: true, isOwner: true,
        owner: "test@example.com", ownersPlan: nil, isCloudSensor: true, canShare: true,
        sharedTo: [], maxHistoryDays: nil)
}

extension CloudTransportTests {
    @MainActor @Test(arguments: [false, true]) func protectedEndpointsPropagateFailuresAndRejectSignedOutRequests(
        signedOut: Bool
    ) async throws {
        let transport = TransportFixture(status: 503, body: "Unavailable")
        defer { transport.close() }
        let user = CloudTestUser()
        if signedOut { user.logout() }
        let service = makeCloudService(api: transport.api, user: user, pool: nil)
        let sensor = cloudTestSensor()
        let mac = sensor.macId!
        let operations: [(String, @MainActor () async throws -> Void)] = [
            ("alerts", { _ = try await service.loadAlerts() }),
            (
                "alert change",
                {
                    try await service.setAlert(
                        type: .temperature, settingType: .state, isEnabled: true,
                        min: 0, max: 30, counter: nil, delay: nil, description: "Warm", for: mac)
                }
            ),
            ("settings", { _ = try await service.getCloudSettings() }),
            ("reset image", { try await service.resetImage(for: mac) }),
            ("upload", { _ = try await service.upload(imageData: Data([1]), mimeType: .png, progress: nil, for: mac) }),
            (
                "sensor settings",
                {
                    _ = try await service.updateSensorSettings(
                        for: sensor, types: ["description"], values: ["Test"], timestamp: nil)
                }
            ),
            (
                "calibration",
                {
                    _ = try await service.update(
                        temperatureOffset: 1, humidityOffset: nil, pressureOffset: nil, for: sensor)
                }
            ),
            ("rename", { _ = try await service.update(name: "New", for: sensor) }),
            ("shares", { _ = try await service.loadShared(for: sensor) }),
            ("owner", { _ = try await service.checkOwner(macId: mac) }),
            (
                "dense sensors",
                {
                    _ = try await service.loadSensorsDense(
                        for: sensor, measurements: true, sharedToOthers: true,
                        sharedToMe: true, alerts: true, settings: true)
                }
            ),
            ("share", { _ = try await service.share(macId: mac, with: "guest@example.com") }),
            ("unshare", { _ = try await service.unshare(macId: mac, with: nil) }),
            ("claim", { _ = try await service.claim(name: "Sauna", macId: mac) }),
            ("contest", { _ = try await service.contest(macId: mac, secret: "secret") }),
            ("unclaim", { _ = try await service.unclaim(macId: mac, removeCloudHistory: false) }),
            ("delete account", { _ = try await service.deleteAccount(email: "test@example.com") }),
            (
                "register push",
                {
                    _ = try await service.registerPNToken(
                        token: "token", type: "ios", name: nil, data: nil, params: nil)
                }
            ),
            ("list push", { _ = try await service.listPNTokens() }),
            ("sensors", { _ = try await service.loadSensors() }),
            ("marketing", { _ = try await service.getMarketingConsent() }),
            ("marketing change", { _ = try await service.set(marketingPreference: true) }),
        ]
        for (name, operation) in operations {
            do { try await operation(); Issue.record("\(name) unexpectedly succeeded") } catch let error
                as RuuviCloudError
            {
                if signedOut {
                    guard case .notAuthorized = error else { Issue.record("\(name): \(error)"); continue }
                } else {
                    guard case .api(.unexpectedHTTPStatusCodeShouldRetry(503)) = error else {
                        Issue.record("\(name): \(error)"); continue
                    }
                }
            }
        }
        #expect(TransportProtocol.state.requests.count == (signedOut ? 0 : operations.count))
    }

    @MainActor @Test func failedSensorMutationsPersistAndReplayEachRequestKindWithoutLosingPayload() async throws {
        let transport = TransportFixture(status: 503, body: "Unavailable")
        defer { transport.close() }
        let database = try CloudQueueFixture()
        defer { database.close() }
        let service = makeCloudService(api: transport.api, user: CloudTestUser(), pool: database.pool)
        let sensor = cloudTestSensor()
        let mac = sensor.macId!
        let changes: [@MainActor () async throws -> Void] = [
            { _ = try await service.update(name: "New name", for: sensor) },
            {
                _ = try await service.update(
                    temperatureOffset: 1, humidityOffset: nil, pressureOffset: nil, for: sensor)
            },
            {
                _ = try await service.update(
                    temperatureOffset: nil, humidityOffset: 10, pressureOffset: nil, for: sensor)
            },
            {
                _ = try await service.update(
                    temperatureOffset: nil, humidityOffset: nil, pressureOffset: 200, for: sensor)
            },
            {
                _ = try await service.updateSensorSettings(
                    for: sensor, types: ["description"], values: ["Indoor"], timestamp: 123)
            },
            {
                try await service.setAlert(
                    type: .temperature, settingType: .upperBound, isEnabled: true, min: nil, max: 30,
                    counter: nil, delay: nil, description: "Warm", for: mac)
            },
            { _ = try await service.unclaim(macId: mac, removeCloudHistory: true) },
            { _ = try await service.unshare(macId: mac, with: "guest@example.com") },
            { _ = try await service.set(chartDuration: 24) },
            { try await service.resetImage(for: mac) },
        ]
        for change in changes {
            do { try await change(); Issue.record("Offline write succeeded") } catch {}
        }
        let requests = try await database.storage.readQueuedRequests()
        #expect(requests.count == changes.count)
        #expect(Set(requests.compactMap(\.uniqueKey)).count == requests.count)
        #expect(requests.allSatisfy { $0.attempts == 1 && $0.status == .failed })
        for request in requests {
            setCloudResponse("{}")
            #expect(try await service.executeQueuedRequest(from: request))
            let expectedData = try #require(request.requestBodyData)
            let actualData = try #require(TransportProtocol.state.body)
            let expected = try #require(
                JSONSerialization.jsonObject(with: expectedData) as? [String: Any])
            let actual = try #require(
                JSONSerialization.jsonObject(with: actualData) as? [String: Any])
            #expect(NSDictionary(dictionary: actual).isEqual(to: expected))
            TransportProtocol.state.configure(status: 503, data: Data(), error: nil, pending: false)
            do {
                _ = try await service.executeQueuedRequest(from: request); Issue.record("Replay swallowed HTTP failure")
            } catch {
                guard case .api(.unexpectedHTTPStatusCodeShouldRetry(503)) = error else {
                    Issue.record("\(error)"); continue
                }
            }
        }
        #expect(try await database.storage.readQueuedRequests().count == changes.count)
    }

    @MainActor @Test func invalidQueuedRequestsNeverReachTheNetwork() async throws {
        let transport = TransportFixture(status: 200, body: cloudSuccess("{}"))
        defer { transport.close() }
        let user = CloudTestUser()
        let service = makeCloudService(api: transport.api, user: user, pool: nil)
        for raw in 0...7 {
            var request = cloudQueuedRequest(
                type: RuuviCloudQueuedRequestType(rawValue: raw), body: Data("not json".utf8))
            do {
                _ = try await service.executeQueuedRequest(from: request); Issue.record("Malformed queue accepted")
            } catch { guard case .api = error else { Issue.record("\(error)"); continue } }
            request.requestBodyData = nil
            do {
                _ = try await service.executeQueuedRequest(from: request); Issue.record("Missing body accepted")
            } catch { guard case .api(.badParameters) = error else { Issue.record("\(error)"); continue } }
        }
        let image = cloudQueuedRequest(
            type: .uploadImage, body: Data(#"{"sensor":"sensor","action":"upload","type":"image/png"}"#.utf8))
        do { _ = try await service.executeQueuedRequest(from: image); Issue.record("Missing image accepted") } catch {
            guard case .api(.badParameters) = error else { Issue.record("\(error)"); return }
        }
        user.logout()
        do { _ = try await service.executeQueuedRequest(from: image); Issue.record("Signed out replay accepted") } catch
        { guard case .notAuthorized = error else { Issue.record("\(error)"); return } }
        #expect(TransportProtocol.state.requests.isEmpty)
    }
}

private func cloudQueuedRequest(type: RuuviCloudQueuedRequestType?, body: Data?, additional: Data? = nil)
    -> RuuviCloudQueuedRequestStruct
{
    RuuviCloudQueuedRequestStruct(
        id: nil, type: type, status: .failed, uniqueKey: "test", requestDate: Date(),
        successDate: nil, attempts: 1, requestBodyData: body, additionalData: additional)
}

extension CloudTransportTests {
    @MainActor @Test(arguments: [MimeType.jpg, .png, .gif])
    func imageUploadUsesSignedURLCorrectContentTypeAndQueuesOriginalBytes(mime: MimeType) async throws {
        let payload = #"{"uploadURL":"https://storage.invalid/sensor?signature=private"}"#
        let transport = TransportFixture(status: 200, body: cloudSuccess(payload))
        defer { transport.close() }
        let database = try CloudQueueFixture()
        defer { database.close() }
        let service = makeCloudService(api: transport.api, user: CloudTestUser(), pool: database.pool)
        let data = Data([0, 1, 2, 255])
        let mac = cloudTestSensor().macId!
        let url = try await service.upload(imageData: data, mimeType: mime, progress: nil, for: mac)
        #expect(url.absoluteString == "https://storage.invalid/sensor?signature=private")
        let requests = TransportProtocol.state.requests
        #expect(requests.count == 2)
        #expect(requests.first?.url?.path == "/upload" && requests.first?.httpMethod == "POST")
        #expect(requests.last?.url == url && requests.last?.httpMethod == "PUT")
        #expect(requests.last?.value(forHTTPHeaderField: "Content-Type") == mime.rawValue)
        #expect(requests.last?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(TransportProtocol.state.body == data)
        #expect(try await database.storage.readQueuedRequests().isEmpty)
        TransportProtocol.state.configure(status: 503, data: Data(), error: nil, pending: false)
        do {
            _ = try await service.upload(imageData: data, mimeType: mime, progress: nil, for: mac);
            Issue.record("Failed upload accepted")
        } catch {
            guard case .api(.unexpectedHTTPStatusCodeShouldRetry(503)) = error else { Issue.record("\(error)"); return }
        }
        let queued = try #require(try await database.storage.readQueuedRequests().first)
        #expect(queued.additionalData == data && queued.type == .uploadImage)
        let queuedData = try #require(queued.requestBodyData)
        let body = try #require(
            JSONSerialization.jsonObject(with: queuedData) as? [String: String])
        #expect(body["type"] == mime.rawValue && body["sensor"] == mac.value)
        setCloudResponse(payload)
        #expect(try await service.executeQueuedRequest(from: queued))
        #expect(TransportProtocol.state.body == data)
    }

    @MainActor @Test(arguments: [400, 503]) func signedUploadHTTPFailureIsClassifiedForRetry(status: Int) async throws {
        let transport = TransportFixture(status: 200, body: "")
        defer { transport.close() }
        TransportProtocol.state.configureResponses([
            TransportResponse(
                status: 200, data: Data(cloudSuccess(#"{"uploadURL":"https://storage.invalid/image"}"#).utf8),
                error: nil, pending: false),
            TransportResponse(status: status, data: Data(), error: nil, pending: false),
        ])
        do {
            _ = try await transport.api.uploadImage(
                .init(sensor: "sensor", action: .upload, mimeType: .jpg),
                imageData: Data([1]), authorization: "key", uploadProgress: nil)
            Issue.record("Upload failure accepted")
        } catch {
            switch error {
            case .unexpectedHTTPStatusCode(400): #expect(status == 400)
            case .unexpectedHTTPStatusCodeShouldRetry(503): #expect(status == 503)
            default: Issue.record("Unexpected upload error: \(error)")
            }
        }
    }

    @MainActor
    @Test(arguments: [
        "{}",
        #"{"type":"unknown","min":null,"max":null,"enabled":null,"counter":null,"description":null,"triggered":null,"triggeredAt":null}"#,
    ])
    func omittedAndNullOptionalAlertFieldsDoNotDiscardAllSensorAlerts(alertJSON: String) async throws {
        let transport = TransportFixture(
            status: 200, body: cloudSuccess("{\"sensors\":[{\"sensor\":\"sensor\",\"alerts\":[\(alertJSON)]}]}"))
        defer { transport.close() }
        let service = makeCloudService(api: transport.api, user: CloudTestUser(), pool: nil)
        let alerts = try await service.loadAlerts()
        let alert = try #require(alerts.first?.alerts?.first)
        #expect(alert.type == nil && alert.enabled == nil && alert.min == nil && alert.max == nil)
        #expect(alert.counter == nil && alert.description == nil && alert.triggeredAt == nil)
    }
}
