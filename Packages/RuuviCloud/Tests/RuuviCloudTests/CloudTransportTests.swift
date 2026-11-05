import Foundation
import Testing
import RuuviContext
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviStorage
import RuuviUser
@testable import RuuviCloud
#if SWIFT_PACKAGE
    @testable import RuuviCloudApi
    @testable import RuuviCloudPure
    import RuuviContextSQLite
    import RuuviLocalUserDefaults
    import RuuviPersistenceSQLite
    import RuuviPoolCoordinator
    import RuuviStorageCoordinator
#endif

@Suite(.serialized)
struct CloudTransportTests {
    @Test(arguments: [nil, "recipient@example.com"] as [String?])
    @MainActor func failedUnsharePersistsOneRetryBeforeReturning(recipient: String?) async throws {
        let transport = TransportFixture(status: 503, body: "Service unavailable")
        defer { transport.close() }
        let database = try CloudQueueFixture()
        defer { database.close() }
        let cloud = makeCloudService(api: transport.api, user: CloudTestUser(), pool: database.pool)
        for _ in 0..<2 {
            do {
                _ = try await cloud.unshare(macId: "AA:BB:CC:DD:EE:FF".mac, with: recipient)
                Issue.record("Unavailable service unexpectedly succeeded")
            } catch {
                guard case .api(.unexpectedHTTPStatusCodeShouldRetry(503)) = error else {
                    Issue.record("Unexpected error: \(error)"); return
                }
            }
        }
        let requests = try await database.storage.readQueuedRequests()
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.type == .unshare)
        #expect(request.attempts == 2)
        let data = try #require(request.requestBodyData)
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body["sensor"] == "AA:BB:CC:DD:EE:FF")
        #expect(body["user"] == recipient)
    }

    // swiftlint:disable:next function_body_length
    @MainActor @Test func everySettingEncodesPersistsRetriesAndRejectsSignedOutWrites() async throws {
        let transport = TransportFixture(status: 200, body: #"{"result":"success","data":{}}"#)
        defer { transport.close() }
        let database = try CloudQueueFixture()
        defer { database.close() }
        let user = CloudTestUser()
        let service = makeCloudService(api: transport.api, user: user, pool: database.pool)
        struct Change {
            let key: RuuviCloudApiSetting
            let value: String
            let apply: @MainActor () async throws(RuuviCloudError) -> Void
        }
        let changes: [Change] = [
            .init(key: .unitTemperature, value: "F") { () async throws(RuuviCloudError) in
                _ = try await service.set(temperatureUnit: .fahrenheit)
            },
            .init(key: .accuracyTemperature, value: "2") { () async throws(RuuviCloudError) in
                _ = try await service.set(temperatureAccuracy: .two)
            },
            .init(key: .unitHumidity, value: "2") { () async throws(RuuviCloudError) in
                _ = try await service.set(humidityUnit: .dew)
            },
            .init(key: .accuracyHumidity, value: "1") { () async throws(RuuviCloudError) in
                _ = try await service.set(humidityAccuracy: .one)
            },
            .init(key: .accuracyHumidityRelative, value: "2") { () async throws(RuuviCloudError) in
                _ = try await service.set(userSetting: .accuracyHumidityRelative, value: "2")
            },
            .init(key: .accuracyHumidityAbsolute, value: "1") { () async throws(RuuviCloudError) in
                _ = try await service.set(userSetting: .accuracyHumidityAbsolute, value: "1")
            },
            .init(key: .accuracyHumidityDewPoint, value: "2") { () async throws(RuuviCloudError) in
                _ = try await service.set(userSetting: .accuracyHumidityDewPoint, value: "2")
            },
            .init(key: .unitPressure, value: "2") { () async throws(RuuviCloudError) in
                _ = try await service.set(pressureUnit: .millimetersOfMercury)
            },
            .init(key: .accuracyPressure, value: "2") { () async throws(RuuviCloudError) in
                _ = try await service.set(pressureAccuracy: .two)
            },
            .init(key: .accuracyPM, value: "1") { () async throws(RuuviCloudError) in
                _ = try await service.set(userSetting: .accuracyPM, value: "1")
            },
            .init(key: .accuracyAcceleration, value: "2") { () async throws(RuuviCloudError) in
                _ = try await service.set(userSetting: .accuracyAcceleration, value: "2")
            },
            .init(key: .accuracyVoltage, value: "2") { () async throws(RuuviCloudError) in
                _ = try await service.set(userSetting: .accuracyVoltage, value: "2")
            },
            .init(key: .chartShowAllPoints, value: "true") { () async throws(RuuviCloudError) in
                _ = try await service.set(showAllData: true)
            },
            .init(key: .chartDrawDots, value: "false") { () async throws(RuuviCloudError) in
                _ = try await service.set(drawDots: false)
            },
            .init(key: .chartShowMinMaxAverage, value: "true") { () async throws(RuuviCloudError) in
                _ = try await service.set(showMinMaxAvg: true)
            },
            .init(key: .cloudModeEnabled, value: "false") { () async throws(RuuviCloudError) in
                _ = try await service.set(cloudMode: false)
            },
            .init(key: .dashboardEnabled, value: "true") { () async throws(RuuviCloudError) in
                _ = try await service.set(dashboard: true)
            },
            .init(key: .dashboardType, value: "simple") { () async throws(RuuviCloudError) in
                _ = try await service.set(dashboardType: .simple)
            },
            .init(key: .dashboardTapActionType, value: "chart") { () async throws(RuuviCloudError) in
                _ = try await service.set(dashboardTapActionType: .chart)
            },
            .init(key: .emailAlertDisabled, value: "true") { () async throws(RuuviCloudError) in
                _ = try await service.set(disableEmailAlert: true)
            },
            .init(key: .pushAlertDisabled, value: "false") { () async throws(RuuviCloudError) in
                _ = try await service.set(disablePushAlert: false)
            },
            .init(key: .profileLanguageCode, value: "FI") { () async throws(RuuviCloudError) in
                _ = try await service.set(profileLanguageCode: "FI")
            },
            .init(key: .dashboardSensorOrder, value: "[\"sensor-b\",\"sensor-a\"]") {
                () async throws(RuuviCloudError) in
                _ = try await service.set(dashboardSensorOrder: ["sensor-b", "sensor-a"])
            },
        ]
        for change in changes {
            try await change.apply()
            let request = try #require(TransportProtocol.state.request)
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path == "/settings")
            let body = try #require(TransportProtocol.state.body)
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(json["name"] as? String == change.key.rawValue)
            #expect(json["value"] as? String == change.value)
            #expect(json["timestamp"] as? Int != nil)
        }
        #expect(try await database.storage.readQueuedRequests().isEmpty)
        TransportProtocol.state.configure(status: 503, data: Data(), error: nil, pending: false)
        for change in changes {
            do {
                try await change.apply()
                Issue.record("Failed cloud setting unexpectedly succeeded")
            } catch {
                guard case .api(.unexpectedHTTPStatusCodeShouldRetry(503)) = error else {
                    Issue.record("Unexpected failure: \(error)"); continue
                }
            }
        }
        let requests = try await database.storage.readQueuedRequests()
        #expect(requests.count == changes.count)
        for change in changes {
            let request = try #require(requests.first { $0.uniqueKey == change.key.rawValue })
            #expect(request.type == .settings)
            let data = try #require(request.requestBodyData)
            let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(json["value"] as? String == change.value)
        }
        user.logout()
        TransportProtocol.state.configure(status: 200, data: Data(), error: nil, pending: false)
        for change in changes {
            do {
                try await change.apply()
                Issue.record("Signed-out mutation unexpectedly succeeded")
            } catch {
                guard case .notAuthorized = error else { Issue.record("Unexpected error: \(error)"); continue }
            }
        }
        #expect(TransportProtocol.state.request == nil)
        #expect(try await database.storage.readQueuedRequests().count == changes.count)
    }

    @Test func registrationUsesPOSTAndDecodesResponse() async throws {
        let fixture = TransportFixture(status: 200, body: #"{"result":"success","data":{"email":"test@example.com"}}"#)
        defer { fixture.close() }
        let response = try await fixture.api.register(.init(email: "test@example.com"))
        #expect(response.email == "test@example.com")
        let request = try #require(TransportProtocol.state.request)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/register")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func verificationEncodesQueryWithoutABody() async throws {
        let fixture = TransportFixture(
            status: 200, body: #"{"result":"success","data":{"email":"a@b.com","accessToken":"key"}}"#)
        defer { fixture.close() }
        _ = try await fixture.api.verify(.init(token: "a+b & c"))
        let request = try #require(TransportProtocol.state.request)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems?.first(where: { $0.name == "token" })?.value == "a+b & c")
        #expect(request.httpMethod == "GET")
        #expect(request.httpBody == nil)
    }

    @Test func authorizationIsSent() async throws {
        let fixture = TransportFixture(
            status: 200, body: #"{"result":"success","data":{"consent":true,"status":"subscribed"}}"#)
        defer { fixture.close() }
        _ = try await fixture.api.getMarketingConsent(authorization: "api-key")
        #expect(TransportProtocol.state.request?.value(forHTTPHeaderField: "Authorization") == "api-key")
    }

    @Test(arguments: [500, 502, 503, 504])
    func serverFailuresAreRetryableEvenWithoutJSON(status: Int) async {
        let fixture = TransportFixture(status: status, body: "upstream unavailable")
        defer { fixture.close() }
        do {
            _ = try await fixture.api.register(.init(email: "a@b.com"))
            Issue.record("Expected an HTTP failure")
        } catch {
            guard case .unexpectedHTTPStatusCodeShouldRetry(let actual) = error else {
                Issue.record("Wrong error: \(error)"); return
            }
            #expect(actual == status)
        }
    }

    @Test func nonSuccessfulHTTPResponseCannotBecomeSuccess() async {
        let fixture = TransportFixture(status: 403, body: #"{"result":"success","data":{"email":"a@b.com"}}"#)
        defer { fixture.close() }
        do {
            _ = try await fixture.api.register(.init(email: "a@b.com"))
            Issue.record("Expected authorization failure")
        } catch {
            guard case .unexpectedHTTPStatusCode(403) = error else {
                Issue.record("Wrong error: \(error)"); return
            }
        }
    }

    @Test func APIErrorSurvivesHTTPErrorResponse() async {
        let fixture = TransportFixture(status: 401, body: #"{"result":"error","code":"ER_UNAUTHORIZED"}"#)
        defer { fixture.close() }
        do {
            _ = try await fixture.api.register(.init(email: "a@b.com"))
            Issue.record("Expected API failure")
        } catch {
            guard case .api(.erUnauthorized) = error else {
                Issue.record("Wrong error: \(error)"); return
            }
        }
    }

    @Test func malformedSuccessfulResponseIsAParsingError() async {
        let fixture = TransportFixture(status: 200, body: "invalid")
        defer { fixture.close() }
        do {
            _ = try await fixture.api.register(.init(email: "a@b.com"))
            Issue.record("Expected parsing failure")
        } catch {
            guard case .parsing = error else { Issue.record("Wrong error: \(error)"); return }
        }
    }

    @Test func transportFailureIsPreserved() async {
        let fixture = TransportFixture(status: 200, body: "", error: URLError(.notConnectedToInternet))
        defer { fixture.close() }
        do {
            _ = try await fixture.api.register(.init(email: "a@b.com"))
            Issue.record("Expected connection failure")
        } catch {
            guard case .networking(let underlying) = error else { Issue.record("Wrong error: \(error)"); return }
            #expect((underlying as? URLError)?.code == .notConnectedToInternet)
        }
    }

    @Test func cancelledRequestTerminates() async {
        let fixture = TransportFixture(status: 200, body: "", pending: true)
        defer { fixture.close() }
        let task = Task { try await fixture.api.register(.init(email: "a@b.com")) }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Cancelled request succeeded")
        } catch {
            guard let domain = error as? RuuviCloudApiError, case .networking(let underlying) = domain else {
                Issue.record("Wrong error: \(error)"); return
            }
            #expect((underlying as? URLError)?.code == .cancelled || underlying is CancellationError)
        }
    }
}

extension CloudTransportTests {
    @Test func malformedAdvertisementLengthsAndHexAreRejectedBeforeDecoding() {
        let valid = "0201061BFF990405" + String(repeating: "00", count: 23)
        #expect(RuuviCloudPure.isValidNetworkPayload(valid))
        #expect(RuuviCloudPure.isValidNetworkPayload(valid.lowercased()))
        for malformed in [
            String(valid.dropLast()), String(valid.dropLast(2)),
            String(repeating: "gg", count: 24), "🙂" + valid, valid + "01", "unsupported",
        ] {
            #expect(!RuuviCloudPure.isValidNetworkPayload(malformed))
        }
    }

    @MainActor @Test func historyContinuesPastUndecodableRecordsAndDeduplicatesPageBoundaries() async throws {
        let transport = TransportFixture(status: 200, body: "")
        defer { transport.close() }
        let database = try CloudQueueFixture()
        defer { database.close() }
        let cloud = makeCloudService(api: transport.api, user: CloudTestUser(), pool: database.pool)
        var first = (1...5000).map { historyMeasurement(timestamp: 1_700_000_000 + $0) }
        first[100]["data"] = "unsupported"
        let second = (5000...5002).map { historyMeasurement(timestamp: 1_700_000_000 + $0) }
        TransportProtocol.state.configurePages(try [historyPage(first), historyPage(second)])
        let records = try await cloud.loadRecords(
            macId: "AA:BB:CC:DD:EE:FF".mac,
            since: Date(timeIntervalSince1970: 1_700_000_000), until: nil)
        #expect(records.count == 5001)
        #expect(Set(records.map(\.id)).count == records.count)
        #expect(records.first?.date == Date(timeIntervalSince1970: 1_700_000_001))
        #expect(records.last?.date == Date(timeIntervalSince1970: 1_700_005_002))
        #expect(records.allSatisfy { $0.source == .ruuviNetwork && $0.version == 5 })
        let requests = TransportProtocol.state.requests
        #expect(requests.count == 2)
        let secondURL = try #require(requests.last?.url)
        let query = URLComponents(url: secondURL, resolvingAgainstBaseURL: false)?.queryItems
        #expect(query?.first { $0.name == "since" }?.value.flatMap(Double.init) == 1_700_005_000)
        #expect(query?.first { $0.name == "limit" }?.value == "5000")
    }

    @MainActor @Test func repeatedFullHistoryPageTerminatesWithoutDuplicates() async throws {
        let transport = TransportFixture(status: 200, body: "")
        defer { transport.close() }
        let database = try CloudQueueFixture()
        defer { database.close() }
        let page = try historyPage((1...5000).map { historyMeasurement(timestamp: 1_700_000_000 + $0) })
        TransportProtocol.state.configurePages([page])
        let cloud = makeCloudService(api: transport.api, user: CloudTestUser(), pool: database.pool)
        let records = try await cloud.loadRecords(
            macId: "AA:BB:CC:DD:EE:FF".mac,
            since: Date(timeIntervalSince1970: 1_700_000_000), until: nil)
        #expect(records.count == 5000)
        #expect(TransportProtocol.state.requests.count == 2)
    }

    @MainActor @Test func entirelyUnsupportedHistoryPageStillAdvancesToValidHistory() async throws {
        let transport = TransportFixture(status: 200, body: "")
        defer { transport.close() }
        let database = try CloudQueueFixture()
        defer { database.close() }
        let invalid = (1...5000).map {
            ["timestamp": 1_700_000_000 + $0, "rssi": -60, "data": "unsupported"] as [String: Any]
        }
        TransportProtocol.state.configurePages(
            try [
                historyPage(invalid),
                historyPage([historyMeasurement(timestamp: 1_700_005_001)]),
            ])
        let cloud = makeCloudService(api: transport.api, user: CloudTestUser(), pool: database.pool)
        let records = try await cloud.loadRecords(
            macId: "AA:BB:CC:DD:EE:FF".mac,
            since: Date(timeIntervalSince1970: 1_700_000_000), until: nil)
        #expect(records.count == 1)
        #expect(TransportProtocol.state.requests.count == 2)
    }

    @MainActor @Test func historyRequiresTimestampsAndStopsAtRequestedEnd() async throws {
        let transport = TransportFixture(status: 200, body: "")
        defer { transport.close() }
        let database = try CloudQueueFixture()
        defer { database.close() }
        let cloud = makeCloudService(api: transport.api, user: CloudTestUser(), pool: database.pool)
        var missing = historyMeasurement(timestamp: 1_700_000_001)
        missing.removeValue(forKey: "timestamp")
        TransportProtocol.state.configurePages(try [historyPage([missing])])
        #expect(
            try await cloud.loadRecords(
                macId: "AA:BB:CC:DD:EE:FF".mac,
                since: Date(timeIntervalSince1970: 1_700_000_000), until: nil
            ).isEmpty)
        let full = (1...5000).map { historyMeasurement(timestamp: 1_700_000_000 + $0) }
        TransportProtocol.state.configurePages(try [historyPage(full)])
        let records = try await cloud.loadRecords(
            macId: "AA:BB:CC:DD:EE:FF".mac,
            since: Date(timeIntervalSince1970: 1_700_000_000), until: Date(timeIntervalSince1970: 1_700_005_000))
        #expect(records.count == 5000)
        #expect(TransportProtocol.state.requests.count == 1)
    }

    @MainActor @Test func cancelledAndSignedOutHistoryDoesNotStartHTTPRequests() async throws {
        let transport = TransportFixture(status: 200, body: "")
        defer { transport.close() }
        let database = try CloudQueueFixture()
        defer { database.close() }
        let user = CloudTestUser()
        let cloud = makeCloudService(api: transport.api, user: user, pool: database.pool)
        let task = Task { @MainActor in
            try await cloud.loadRecords(macId: "AA:BB:CC:DD:EE:FF".mac, since: Date(), until: nil)
        }
        task.cancel()
        do {
            _ = try await task.value
            Issue.record("Cancelled history succeeded")
        } catch {
            guard let error = error as? RuuviCloudError,
                case .api(.networking(let underlying)) = error, underlying is CancellationError
            else {
                Issue.record("Unexpected cancellation: \(error)"); return
            }
        }
        user.logout()
        do {
            _ = try await cloud.loadRecords(macId: "AA:BB:CC:DD:EE:FF".mac, since: Date(), until: nil)
            Issue.record("Signed-out history succeeded")
        } catch {
            guard case .notAuthorized = error else { Issue.record("Unexpected error: \(error)"); return }
        }
        #expect(TransportProtocol.state.requests.isEmpty)
    }

    private func historyMeasurement(timestamp: Int) -> [String: Any] {
        // Complete BLE advertisement: flags followed by Ruuvi manufacturer data, format 5.
        ["timestamp": timestamp, "rssi": -60, "data": "0201061BFF990405" + String(repeating: "00", count: 23)]
    }

    private func historyPage(_ measurements: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["result": "success", "data": ["measurements": measurements]])
    }

}

struct TransportFixture {
    let session: URLSession
    let api: RuuviCloudApiURLSession

    init(status: Int, body: String, error: Error? = nil, pending: Bool = false) {
        TransportProtocol.state.configure(status: status, data: Data(body.utf8), error: error, pending: pending)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TransportProtocol.self]
        session = URLSession(configuration: configuration)
        api = RuuviCloudApiURLSession(baseUrl: URL(string: "https://transport.invalid")!, session: session)
    }
    func close() { session.invalidateAndCancel() }
}

struct TransportResponse {
    let status: Int
    let data: Data
    let error: Error?
    let pending: Bool
}

final class TransportState: @unchecked Sendable {
    private let lock = NSLock()
    private var capturedRequest: URLRequest?
    private var capturedBody: Data?
    private var capturedRequests: [URLRequest] = []
    private var pages: [TransportResponse] = []
    var requests: [URLRequest] { lock.withLock { capturedRequests } }
    func configureResponses(_ values: [TransportResponse]) {
        lock.withLock {
            pages = values
            response = values.last ?? TransportResponse(status: 200, data: Data(), error: nil, pending: false)
            capturedRequests = []
            capturedRequest = nil
            capturedBody = nil
        }
    }
    func configurePages(_ data: [Data]) {
        lock.withLock {
            pages = data.map { TransportResponse(status: 200, data: $0, error: nil, pending: false) }
            response = pages.last ?? TransportResponse(status: 200, data: Data(), error: nil, pending: false)
            capturedRequests = []
        }
    }
    private var response = TransportResponse(status: 200, data: Data(), error: nil, pending: false)

    var request: URLRequest? { lock.withLock { capturedRequest } }
    var body: Data? { lock.withLock { capturedBody } }
    func configure(status: Int, data: Data, error: Error?, pending: Bool) {
        lock.withLock {
            response = TransportResponse(status: status, data: data, error: error, pending: pending);
            capturedRequest = nil
            capturedBody = nil
            capturedRequests = []
            pages = []
        }
    }
    func capture(_ request: URLRequest) -> TransportResponse {
        lock.withLock {
            capturedRequest = request
            capturedRequests.append(request)
            capturedBody =
                request.httpBody
                ?? request.httpBodyStream.map { stream in
                    stream.open()
                    defer { stream.close() }
                    var data = Data()
                    var buffer = [UInt8](repeating: 0, count: 4096)
                    while stream.hasBytesAvailable {
                        let count = stream.read(&buffer, maxLength: buffer.count)
                        guard count > 0 else { break }
                        data.append(contentsOf: buffer.prefix(count))
                    }
                    return data
                }
            return pages.isEmpty ? response : pages.removeFirst()
        }
    }
}

final class TransportProtocol: URLProtocol, @unchecked Sendable {
    static let state = TransportState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let fixture = Self.state.capture(request)
        if fixture.pending { return }
        if let error = fixture.error { client?.urlProtocol(self, didFailWithError: error); return }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: fixture.status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: fixture.data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

final class CloudTestUser: RuuviUser {
    var apiKey: String? = "test-key"
    var email: String? = "test@example.com"
    var isAuthorized: Bool { apiKey != nil }
    func login(apiKey: String) { self.apiKey = apiKey }
    func logout() { apiKey = nil; email = nil }
}

@MainActor struct CloudQueueFixture {
    let directory: URL
    let persistence: RuuviPersistenceSQLite
    let pool: RuuviPool
    let storage: RuuviStorage
    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let context = try SQLiteContextFactoryGRDB().create(at: directory.appendingPathComponent("cloud.sqlite"))
        persistence = RuuviPersistenceSQLite(context: context)
        let local = RuuviLocalFactoryUserDefaults()
        pool = RuuviPoolFactoryCoordinator().create(
            sqlite: persistence, idPersistence: local.createLocalIDs(), settings: local.createLocalSettings(),
            connectionPersistence: local.createLocalConnections())
        storage = RuuviStorageFactoryCoordinator().create(sqlite: persistence)
    }
    func close() {
        try? persistence.database.dbPool.close()
        try? FileManager.default.removeItem(at: directory)
    }
}
