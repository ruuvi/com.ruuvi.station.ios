import Combine
import Foundation
import RuuviDFU
import RuuviFirmware
import RuuviOntology
import XCTest
@testable import station

@MainActor final class FirmwareNetworkingTests: XCTestCase {
    func testTagDownloadsBothArchivesLazilyAndKeepsTheirIdentityWhenTheyFinishOutOfOrder() async throws {
        let session = AppDownloadSession()
        let repository = AppDownloadRepository()
        let interactor = DFUInteractor(firmwareType: .latest, session: session, firmwareRepository: repository)
        let release = tagRelease()
        let publisher = interactor.download(release: release, currentRelease: .init(version: "3.0.0"))
        XCTAssertTrue(session.downloads.isEmpty)
        let completed = expectation(description: "Archives downloaded")
        var files: [URL] = []
        var progressCount = 0
        let token = publisher.sink(
            receiveCompletion: {
                if case .failure(let error) = $0 { XCTFail("Unexpected \(error)") }
                completed.fulfill()
            },
            receiveValue: {
                XCTAssertTrue(Thread.isMainThread)
                switch $0 {
                case .progress: progressCount += 1
                case .response(let app, let full, let additional):
                    files = [app, full]
                    XCTAssertTrue(additional.isEmpty)
                }
            })
        XCTAssertEqual(session.downloads.map { $0.url.lastPathComponent }, ["app.zip", "full.zip"])
        session.downloads[0].task.progress.completedUnitCount = 50
        try session.finish(1)
        try session.finish(0)
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertGreaterThan(progressCount, 0)
        XCTAssertEqual(files.map(\.lastPathComponent), ["default_app.zip", "default.zip"])
        XCTAssertEqual(repository.names, ["default.zip", "default_app.zip"])
        withExtendedLifetime(token) {}
    }

    func testAirDownloadsOnlyPrimaryForNormalBuildsAndAllAssetsForDevelopmentBuilds() async throws {
        for version in [nil, "1.0.0", "1.0.0-dev", "1.0.0+dev"] as [String?] {
            let session = AppDownloadSession()
            let interactor = DFUInteractor(
                deviceType: .ruuviAir, firmwareType: .latest,
                session: session, firmwareRepository: AppDownloadRepository())
            let isDev = version?.contains("dev") == true
            let completed = expectation(description: "Air downloads completed")
            var files: [URL] = []
            let token = interactor.download(release: airRelease(), currentRelease: version.map { .init(version: $0) })
                .sink(
                    receiveCompletion: {
                        if case .failure(let error) = $0 { XCTFail("Unexpected \(error)") }
                        completed.fulfill()
                    },
                    receiveValue: {
                        if case .response(let app, let full, let additional) = $0 {
                            XCTAssertEqual(app, full)
                            files = [app] + additional
                        }
                    })
            XCTAssertEqual(session.downloads.count, isDev ? 3 : 1)
            for index in session.downloads.indices.reversed() { try session.finish(index) }
            await fulfillment(of: [completed], timeout: 2)
            XCTAssertEqual(files.map(\.lastPathComponent), isDev ? ["app.bin", "loader.bin", "boot.bin"] : ["app.bin"])
            withExtendedLifetime(token) {}
        }
    }

    func testMissingAndInvalidAssetsFailWithoutStartingDownloads() async {
        for device: RuuviDeviceType in [.ruuviTag, .ruuviAir] {
            for release in [
                LatestRelease(version: "1", assets: []),
                LatestRelease(version: "1", assets: [.init(name: "default_app.zip", downloadUrlString: "relative")]),
                LatestRelease(
                    version: "1", assets: [.init(name: "default.zip", downloadUrlString: "https://example.com/full")]),
            ] {
                // A single valid URL is a valid Air primary asset.
                if device == .ruuviAir, release.assets.first?.downloadUrlString.hasPrefix("https:") == true { continue }
                let session = AppDownloadSession()
                let interactor = DFUInteractor(deviceType: device, firmwareType: .latest, session: session)
                let completed = expectation(description: "Invalid assets rejected")
                let token = interactor.download(release: release, currentRelease: nil).sink(
                    receiveCompletion: {
                        guard case .failure(let error) = $0 else { return XCTFail("Expected failure") }
                        XCTAssertEqual((error as? URLError)?.code, .badURL)
                        completed.fulfill()
                    }, receiveValue: { _ in XCTFail("Invalid assets produced firmware") })
                await fulfillment(of: [completed], timeout: 2)
                XCTAssertTrue(session.downloads.isEmpty)
                withExtendedLifetime(token) {}
            }
        }
    }

    func testCancellingOneAirDownloadLeavesTheOtherSubscriptionActive() async throws {
        let session = AppDownloadSession()
        let interactor = DFUInteractor(
            deviceType: .ruuviAir, firmwareType: .latest,
            session: session, firmwareRepository: AppDownloadRepository())
        let publisher = interactor.download(release: airRelease(), currentRelease: nil)
        let first = publisher.sink(
            receiveCompletion: { _ in XCTFail("Cancelled download completed") },
            receiveValue: { _ in
                XCTFail("Cancelled download produced a value")
            })
        let completed = expectation(description: "Second download remains independent")
        let second = publisher.sink(
            receiveCompletion: {
                if case .failure(let error) = $0 { XCTFail("Unexpected \(error)") }
                completed.fulfill()
            }, receiveValue: { _ in })
        XCTAssertEqual(session.downloads.count, 2)
        first.cancel()
        XCTAssertEqual(session.downloads.map { $0.task.cancelCount }, [1, 0])
        try session.finish(1)
        await fulfillment(of: [completed], timeout: 2)
        withExtendedLifetime(second) {}
    }

    func testRepositoryFailuresAreReportedInsteadOfBypassingFirmwareValidation() async throws {
        let session = AppDownloadSession()
        let repository = AppDownloadRepository()
        repository.fail = true
        let interactor = DFUInteractor(
            deviceType: .ruuviAir, firmwareType: .latest,
            session: session, firmwareRepository: repository)
        let completed = expectation(description: "Storage failure reported")
        let token = interactor.download(release: airRelease(), currentRelease: nil).sink(
            receiveCompletion: {
                guard case .failure(let error) = $0 else { return XCTFail("Expected failure") }
                XCTAssertEqual((error as? URLError)?.code, .cannotWriteToFile)
                completed.fulfill()
            }, receiveValue: { if case .response = $0 { XCTFail("Failed storage produced firmware") } })
        try session.finish(0)
        await fulfillment(of: [completed], timeout: 2)
        withExtendedLifetime(token) {}
    }

    func testReleaseMetadataUsesNativeSessionAndSelectsEveryAirChannel() async throws {
        let tag = try JSONEncoder().encode(tagRelease())
        let session = metadataSession(data: tag)
        defer { session.invalidateAndCancel() }
        let release = try await result(DFUInteractor(firmwareType: .latest, session: session).loadLatestRelease())
        XCTAssertEqual(release.version, "3.0.0")
        XCTAssertEqual(release.assets.count, 2)
        for channel: RuuviDFUFirmwareType in [.latest, .alpha, .beta] {
            let data = try airMetadata()
            let session = metadataSession(data: data)
            defer { session.invalidateAndCancel() }
            let interactor = DFUInteractor(deviceType: .ruuviAir, firmwareType: channel, session: session)
            let release = try await result(interactor.loadLatestRelease())
            let expected = channel == .latest ? "1.0.0" : (channel == .alpha ? "1.1.0-alpha" : "1.1.0-beta")
            XCTAssertEqual(release.version, expected)
            XCTAssertEqual(release.assets.map(\.name), ["app.bin", "loader.bin", "boot.bin"])
        }
    }

    func testMetadataHTTPFailuresMalformedJSONAndMissingChannelsFailInsteadOfLeavingTheScreenLoading() async throws {
        let valid = try airMetadata()
        let fixtures: [(Int, Data)] = [
            (404, valid), (500, valid), (200, Data("invalid JSON".utf8)),
            (200, Data(#"{"result":"success","data":{}}"#.utf8)),
            (200, Data(#"{"result":"error","data":{}}"#.utf8)),
        ]
        for (status, data) in fixtures {
            let session = metadataSession(data: data, status: status)
            defer { session.invalidateAndCancel() }
            let interactor = DFUInteractor(deviceType: .ruuviAir, firmwareType: .latest, session: session)
            do { _ = try await result(interactor.loadLatestRelease()); XCTFail("Expected metadata failure") } catch {
                if status != 200 { XCTAssertEqual((error as? URLError)?.code, .badServerResponse) }
            }
        }
    }

    private func result(_ publisher: AnyPublisher<LatestRelease, Error>) async throws -> LatestRelease {
        let completed = expectation(description: "Release response")
        var output: LatestRelease?
        var failure: Error?
        let token = publisher.sink(
            receiveCompletion: {
                XCTAssertTrue(Thread.isMainThread)
                if case .failure(let error) = $0 { failure = error }
                completed.fulfill()
            }, receiveValue: { output = $0 })
        await fulfillment(of: [completed], timeout: 2)
        withExtendedLifetime(token) {}
        if let failure { throw failure }
        return try XCTUnwrap(output, "Release publisher must produce a release or an error")
    }

    private func metadataSession(data: Data, status: Int = 200) -> URLSession {
        let key = UUID().uuidString
        MetadataProtocol.register(key: key, data: data, status: status)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MetadataProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Firmware-Test": key]
        return URLSession(configuration: configuration)
    }

    private func tagRelease() -> LatestRelease {
        .init(
            version: "3.0.0",
            assets: [
                .init(name: "default.zip", downloadUrlString: "https://example.com/full.zip"),
                .init(name: "default_app.zip", downloadUrlString: "https://example.com/app.zip"),
            ])
    }
    private func airRelease() -> LatestRelease {
        .init(
            version: "1.0.0",
            assets: ["app.bin", "loader.bin", "boot.bin"].map {
                .init(name: $0, downloadUrlString: "https://example.com/" + $0)
            })
    }
    private func airMetadata() throws -> Data {
        var channels: [String: Any] = [:]
        for (channel, version) in [("latest", "1.0.0"), ("alpha", "1.1.0-alpha"), ("beta", "1.1.0-beta")] {
            channels[channel] = [
                "version": version, "url": "https://example.com/firmware", "created_at": "2026-11-05",
                "versionCode": 1, "fileName": "app.bin", "fwloader": "loader.bin", "mcuboot": "boot.bin",
            ]
        }
        return try JSONSerialization.data(withJSONObject: ["result": "success", "data": channels])
    }
}

private final class AppDownloadSession: URLSession, @unchecked Sendable {
    struct Download {
        let url: URL
        let task: AppDownloadTask
        let completion: @Sendable (URL?, URLResponse?, Error?) -> Void
    }
    var downloads: [Download] = []
    override func downloadTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void
    ) -> URLSessionDownloadTask {
        let task = AppDownloadTask()
        downloads.append(.init(url: request.url!, task: task, completion: completionHandler))
        return task
    }
    func finish(_ index: Int) throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1, 2, 3]).write(to: file)
        let download = downloads[index]
        download.completion(
            file, HTTPURLResponse(url: download.url, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
    }
}
private final class AppDownloadTask: URLSessionDownloadTask, @unchecked Sendable {
    private let downloadProgress = Progress(totalUnitCount: 100)
    override var progress: Progress { downloadProgress }
    var cancelCount = 0
    override func resume() {}
    override func cancel() { cancelCount += 1 }
}
private final class AppDownloadRepository: FirmwareRepository {
    var names: [String] = []
    var fail = false
    func save(name: String, fileUrl: URL) throws -> URL {
        defer { try? FileManager.default.removeItem(at: fileUrl) }
        if fail { throw URLError(.cannotWriteToFile) }
        names.append(name)
        return URL(fileURLWithPath: "/saved/" + name)
    }
}
private final class MetadataProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var fixtures: [String: (Data, Int)] = [:]
    static func register(key: String, data: Data, status: Int) {
        lock.lock(); defer { lock.unlock() }
        fixtures[key] = (data, status)
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        let fixture = Self.fixtures.removeValue(forKey: request.value(forHTTPHeaderField: "X-Firmware-Test") ?? "")
        Self.lock.unlock()
        guard let (data, status) = fixture else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
