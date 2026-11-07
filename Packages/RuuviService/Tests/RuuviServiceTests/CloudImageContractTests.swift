import Foundation
import RuuviLocal
import RuuviOntology
import UIKit
import XCTest
@testable import RuuviService
#if SWIFT_PACKAGE
    import RuuviServiceCloudSync
#endif

@MainActor final class CloudImageContractTests: XCTestCase {
    func testDownloadedImageIsPersistedAtFullQualityBeforeItsCacheIsMarked() async throws {
        let images = PropertiesImagesSpy()
        let response = ImageResponseFixture(data: try XCTUnwrap(images.image.pngData()))
        defer { response.close() }
        let fixture = try CloudSyncFixture(imageSession: response.session, images: images)
        defer { fixture.close() }
        var sensor = fixture.cloudSensor()
        sensor.picture = response.url
        let saved = try await fixture.service.syncImage(sensor: sensor)
        XCTAssertEqual(saved, images.url)
        XCTAssertEqual(images.writes.map(\.0), [sensor.id])
        XCTAssertEqual(images.writes.map(\.1), [1])
        XCTAssertEqual(images.writtenImages.first?.cgImage?.width, images.image.cgImage?.width)
        XCTAssertEqual(images.writtenImages.first?.cgImage?.height, images.image.cgImage?.height)
        XCTAssertEqual(images.cacheMarks, [sensor.id])
    }

    func testInvalidHttpBodiesNetworkFailuresAndDiskFailuresNeverMarkTheImageCached() async throws {
        for scenario in 0..<4 {
            let images = PropertiesImagesSpy()
            let response = ImageResponseFixture(
                data: scenario == 1 ? Data("not an image".utf8) : try XCTUnwrap(images.image.pngData()),
                status: scenario == 0 ? 503 : 200, error: scenario == 2 ? URLError(.notConnectedToInternet) : nil)
            defer { response.close() }
            let fixture = try CloudSyncFixture(imageSession: response.session, images: images)
            defer { fixture.close() }
            var sensor = fixture.cloudSensor()
            sensor.picture = response.url
            if scenario == 3 { images.localFailure = .failedToGetDocumentsDirectory }
            do {
                _ = try await fixture.service.syncImage(sensor: sensor)
                XCTFail("Expected image failure for scenario \(scenario)")
            } catch {
                switch (scenario, error) {
                case (0, .networking(let error)):
                    XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
                case (1, .failedToParseNetworkResponse): break
                case (2, .networking(let error)):
                    XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
                case (3, .ruuviLocal(.failedToGetDocumentsDirectory)): break
                default: XCTFail("Unexpected image error: \(error)")
                }
            }
            XCTAssertEqual(images.writes.count, scenario == 3 ? 1 : 0)
            XCTAssertTrue(images.cacheMarks.isEmpty)
        }
    }
}

private final class ImageResponseFixture {
    let url = URL(string: "https://image.test/" + UUID().uuidString)!
    let session: URLSession
    init(data: Data, status: Int = 200, error: URLError? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageResponseProtocol.self]
        session = URLSession(configuration: configuration)
        ImageResponseProtocol.set(.init(data: data, status: status, error: error), for: url)
    }
    func close() { session.invalidateAndCancel(); ImageResponseProtocol.set(nil, for: url) }
}

private final class ImageResponseProtocol: URLProtocol {
    struct Response { let data: Data; let status: Int; let error: URLError? }
    private static let lock = NSLock()
    private static var responses = [URL: Response]()
    static func set(_ response: Response?, for url: URL) {
        lock.lock(); defer { lock.unlock() }; responses[url] = response
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        Self.lock.lock()
        let response = Self.responses[url]
        Self.lock.unlock()
        guard let response else { client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return }
        if let error = response.error { client?.urlProtocol(self, didFailWithError: error); return }
        let http = HTTPURLResponse(url: url, statusCode: response.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
