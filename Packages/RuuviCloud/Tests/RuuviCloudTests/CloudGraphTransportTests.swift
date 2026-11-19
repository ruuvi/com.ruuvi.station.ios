#if canImport(RuuviCloudPure)
@testable import RuuviCloudApi
#endif
@testable import RuuviCloud
import XCTest
#if canImport(RuuviUser)
import RuuviUser
#if canImport(RuuviCloudPure)
import RuuviCloudPure
#endif
#endif

final class CloudGraphTransportTests: XCTestCase {
    private let sensor = "AA:BB:CC:DD:EE:FF"
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [GraphMockProtocol.self]
        session = URLSession(configuration: config)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        GraphMockProtocol.handler = nil
        GraphMockProtocol.stopped = nil
        super.tearDown()
    }

    func testPostUsesCurrentCloudAuthorizationAndCompactContract() async throws {
        let expected = try response()
        GraphMockProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://cloud.example.invalid/api/history/graph")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-key")
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let stream = try XCTUnwrap(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var bytes = [UInt8](repeating: 0, count: 4096)
            let length = stream.read(&bytes, maxLength: bytes.count)
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(bytes.prefix(length))) as? [String: Any])
            XCTAssertEqual(body["format"] as? String, "columns")
            XCTAssertEqual(body["maxPoints"] as? Int, 1500)
            XCTAssertEqual(body["targetPoints"] as? Int, 1000)
            return (200, [:], expected)
        }
        let result = try await load()
        XCTAssertEqual(result.series.first?.samples(.temperature).first?.value, 22)
    }

    func testBothFormatsAcceptContainedServerBoundsAndRejectForeignSensors() async throws {
        for compact in [false, true] {
            for (since, until, valid): (Int, Int, Bool) in [
                (100, 200, true), (103, 198, true), (150, 150, true),
                (99, 200, false), (100, 201, false), (180, 179, false),
            ] {
                let data = try response(since: since, until: until, compact: compact, empty: true)
                GraphMockProtocol.handler = { _ in (200, [:], data) }
                do { _ = try await load(); XCTAssertTrue(valid) } catch { XCTAssertFalse(valid, "Valid subscription/server-clock clamp must be accepted") }
            }
        }
        let foreign = try response(sensor: "11:22:33:44:55:66")
        GraphMockProtocol.handler = { _ in (200, [:], foreign) }
        do { _ = try await load(); XCTFail("Foreign series accepted") } catch { }
    }

    func testHttpErrorsDoNotBecomeEmptySuccessOrAutomaticRawDownloads() async throws {
        for status in [401, 403, 404, 413, 429, 503] {
            var count = 0
            GraphMockProtocol.handler = { _ in
                count += 1
                return (status, ["Retry-After": "7"], Data("{\"result\":\"error\"}".utf8))
            }
            do { _ = try await load(); XCTFail("Expected HTTP error") } catch let error as CloudGraphError {
                if status == 404 {
                    guard case .unavailable = error else { return XCTFail("Expected unavailable endpoint") }
                } else {
                    guard case .http(let actual, let delay) = error else { return XCTFail("Expected HTTP error") }
                    XCTAssertEqual(actual, status)
                    XCTAssertEqual(delay, 7)
                }
            }
            XCTAssertEqual(count, 1)
        }
    }

    func testCancellationStopsTheNetworkRequest() async throws {
        let started = expectation(description: "network started")
        let stopped = expectation(description: "network cancelled")
        GraphMockProtocol.handler = { _ in started.fulfill(); return nil }
        GraphMockProtocol.stopped = { stopped.fulfill() }
        let task = Task { try await load() }
        await fulfillment(of: [started], timeout: 2)
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled request succeeded") } catch { }
        await fulfillment(of: [stopped], timeout: 2)
    }

    #if canImport(RuuviUser)
    func testCurrentCloudClientRejectsResultsFromThePreviousAccount() async throws {
        let user = GraphSessionUser()
        user.login(apiKey: "synthetic-first-account")
        let api = RuuviCloudApiURLSession(baseUrl: URL(string: "https://cloud.example.invalid")!, graphSession: session)
        let cloud = RuuviCloudPure(api: api, user: user, pool: nil)
        let fixture = try response()
        GraphMockProtocol.handler = { _ in
            user.login(apiKey: "synthetic-second-account")
            return (200, [:], fixture)
        }
        do {
            _ = try await cloud.loadGraph(CloudGraphQuery(sensors: [sensor], since: 100, until: 200))
            XCTFail("Response from the previous account was published")
        } catch let error as CloudGraphError {
            guard case .unauthorized = error else { return XCTFail("Expected session rejection") }
        }
    }
    #endif

    func testSubscriptionLimitsDoNotDependOnPlanNamesOrLocalRetention() {
        XCTAssertNil(CloudGraphQuery.historyHours(maxHistoryDays: nil))
        XCTAssertNil(CloudGraphQuery.historyHours(maxHistoryDays: 0))
        XCTAssertNil(CloudGraphQuery.historyHours(maxHistoryDays: -1))
        for days in [1, 10, 180, 731, 1095, 1096] {
            XCTAssertEqual(CloudGraphQuery.historyHours(maxHistoryDays: days), days * 24)
        }
        XCTAssertEqual(CloudGraphQuery.historyHours(maxHistoryDays: Int.max), 1096 * 24)
    }

    func testBoundsAndThreeYearRequestBudget() throws {
        XCTAssertNoThrow(try CloudGraphQuery(sensors: [sensor], since: 1, until: 1 + 1096 * 86400))
        XCTAssertThrowsError(try CloudGraphQuery(sensors: [sensor], since: 1, until: 2 + 1096 * 86400))
        XCTAssertThrowsError(try CloudGraphQuery(sensors: [sensor, sensor], since: 1, until: 2))
        XCTAssertThrowsError(try CloudGraphQuery(sensors: [sensor], since: 2, until: 1))
        XCTAssertThrowsError(try CloudGraphQuery(sensors: [sensor], since: -1, until: 1))
        XCTAssertThrowsError(try CloudGraphQuery(sensors: [sensor], since: 0, until: 1, metrics: []))
    }

    func testOversizedBodyFailsBeforeJsonExpansion() async throws {
        GraphMockProtocol.handler = { _ in (200, [:], Data(repeating: 32, count: 4 * 1024 * 1024 + 1)) }
        do { _ = try await load(); XCTFail("Oversized body accepted") } catch let error as CloudGraphError {
            guard case .invalid = error else { return XCTFail("Expected validation failure") }
        }
    }

    private func load() async throws -> CloudGraphResponse {
        try await CloudGraphTransport.load(
            CloudGraphQuery(sensors: [sensor], since: 100, until: 200),
            baseURL: URL(string: "https://cloud.example.invalid/api")!,
            authorization: "synthetic-key", session: session
        )
    }

    private func response(since: Int = 100, until: Int = 200, compact: Bool = true,
                          empty: Bool = false, sensor: String = "AA:BB:CC:DD:EE:FF") throws -> Data {
        var series: [String: Any] = [
            "sensor": sensor, "name": "Synthetic", "since": since, "until": until, "resolutionSeconds": 10,
            "offsetTemperature": 1, "offsetHumidity": 0, "offsetPressure": 0,
        ]
        if compact {
            series["timestamps"] = empty ? [] : [100]
            series["metrics"] = empty ? [:] : [
                "temperature": ["mean": [21], "min": [20], "max": [22], "count": [2]]
            ]
        } else {
            series["points"] = empty ? [] : [["timestamp": 100, "metrics": [
                "temperature": ["mean": 21, "min": 20, "max": 22, "count": 2]
            ],],]
        }
        return try JSONSerialization.data(withJSONObject: [
            "result": "success", "data": ["series": [series], "maxPoints": 1500, "targetPoints": 1000]
        ])
    }
}

private final class GraphMockProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, [String: String], Data)?)?
    static var stopped: (() -> Void)?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let (status, headers, data) = try Self.handler?(request) else { return }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { Self.stopped?() }
}

#if canImport(RuuviUser)
private final class GraphSessionUser: RuuviUser {
    private let lock = NSLock()
    private var key: String?
    var email: String?
    var isAuthorized: Bool { apiKey != nil }
    var apiKey: String? {
        lock.lock()
        defer { lock.unlock() }
        return key
    }
    func login(apiKey: String) { lock.lock(); key = apiKey; lock.unlock() }
    func logout() { lock.lock(); key = nil; lock.unlock() }
}
#endif
