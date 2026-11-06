import Combine
import Foundation
import XCTest
@testable import RuuviFirmware

@MainActor final class ModuleFirmwareNetworkingTests: XCTestCase {
    func testReleaseMetadataDecodesOnTheMainQueueAndHttpOrJsonFailuresPropagate() async {
        for (body, status, succeeds) in [
            (
                #"{"tag_name":"3.31.1","assets":[{"name":"default_app.zip","browser_download_url":"https://example.com/app.zip"}]}"#,
                200, true
            ),
            (#"{"tag_name":"3.31.1","assets":[]}"#, 503, false),
            ("invalid-json", 200, false),
        ] {
            let fixture = ModuleFirmwareFixture()
            let configuration = URLSessionConfiguration.ephemeral
            let key = UUID().uuidString
            configuration.protocolClasses = [ModuleMetadataProtocol.self]
            configuration.httpAdditionalHeaders = ["X-Firmware-Fixture": key]
            ModuleMetadataProtocol.register(key, data: Data(body.utf8), status: status)
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }
            let interactor = fixture.interactor(session: session)
            var completed = false
            var releases = [GitHubRelease]()
            var failure: Error?
            let token = interactor.loadLatestGitHubRelease().sink(
                receiveCompletion: {
                    XCTAssertTrue(Thread.isMainThread)
                    if case .failure(let error) = $0 { failure = error }
                    completed = true
                }, receiveValue: { releases.append($0) })
            await waitForFirmwareState("release metadata finished") { completed }
            if succeeds {
                XCTAssertNil(failure)
                XCTAssertEqual(releases.first?.version, "3.31.1")
                XCTAssertEqual(releases.first?.defaultAppZipName, "default_app.zip")
            } else {
                XCTAssertNotNil(failure)
                XCTAssertTrue(releases.isEmpty)
            }
            withExtendedLifetime(token) {}
        }
    }

    func testIncompleteReleaseCannotStartAnArchiveDownload() {
        let fixture = ModuleFirmwareFixture()
        let interactor = fixture.interactor()
        for assets: [GitHubRelease.Asset] in [
            [], [.init(name: "default.zip", downloadUrlString: "https://example.com/full.zip")],
        ] {
            var failure: Error?
            let token = interactor.download(release: .init(version: "3.31.1", assets: assets)).sink(
                receiveCompletion: { if case .failure(let error) = $0 { failure = error } },
                receiveValue: { _ in XCTFail("Incomplete release started downloading") })
            XCTAssertEqual((failure as? URLError)?.code, .badURL)
            withExtendedLifetime(token) {}
        }
    }
}

private final class ModuleMetadataProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var fixtures = [String: (Data, Int)]()
    static func register(_ key: String, data: Data, status: Int) { lock.withLock { fixtures[key] = (data, status) } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let fixture = Self.lock.withLock {
            Self.fixtures.removeValue(forKey: request.value(forHTTPHeaderField: "X-Firmware-Fixture") ?? "")
        }
        guard let (data, status) = fixture, let url = request.url,
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
