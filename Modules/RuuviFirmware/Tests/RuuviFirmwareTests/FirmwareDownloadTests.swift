import Combine
import Foundation
@testable import RuuviFirmware
import XCTest

final class FirmwareDownloadTests: XCTestCase {
    private let url = URL(string: "https://example.com/firmware.zip")!

    func testDownloadStartsOnDemandOnceAndMovesTheDownloadedBytesBeforeFinishing() throws {
        let session = DownloadSession()
        let subscriber = DownloadSubscriber()
        let publisher = session.downloadTaskPublisher(for: url, progress: Progress(totalUnitCount: 1))
        publisher.receive(subscriber: subscriber)
        XCTAssertTrue(session.requests.isEmpty)
        subscriber.subscription?.request(.none)
        XCTAssertTrue(session.requests.isEmpty)
        subscriber.subscription?.request(.unlimited)
        subscriber.subscription?.request(.max(1))
        XCTAssertEqual(session.requests.map(\.url), [url])
        XCTAssertEqual(session.download.resumeCount, 1)
        let source = try temporaryDownload()
        session.complete(source, response(status: 200), nil)
        let saved = try XCTUnwrap(subscriber.files.first)
        defer { try? FileManager.default.removeItem(at: saved) }
        XCTAssertEqual(try Data(contentsOf: saved), Data([1, 2, 3, 255]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(subscriber.completions.count, 1)
        if case .failure = subscriber.completions.first { XCTFail("Expected a successful download") }
        subscriber.subscription?.request(.unlimited)
        XCTAssertEqual(session.requests.count, 1)
        session.complete(nil, nil, URLError(.cancelled))
        XCTAssertEqual(subscriber.completions.count, 1)
    }

    func testHTTPFailuresMissingResponsesAndAllTransportErrorsFailWithoutDeliveringFirmware() throws {
        for status in [301, 400, 404, 500, 503] {
            let source = try temporaryDownload()
            defer { try? FileManager.default.removeItem(at: source) }
            assertFailure(file: source, response: response(status: status), error: nil, expected: .badServerResponse)
            XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        }
        assertFailure(file: nil, response: nil, error: nil, expected: .badServerResponse)
        assertFailure(file: nil, response: response(status: 200), error: nil, expected: .badURL)
        assertFailure(file: nil, response: nil, error: URLError(.timedOut), expected: .timedOut)
        assertFailure(
            file: nil, response: response(status: 200),
            error: NSError(domain: "Transport", code: 7), expected: .unknown)
        assertFailure(
            file: URL(fileURLWithPath: "/missing-firmware-\(UUID())"),
            response: response(status: 200), error: nil, expected: .cannotCreateFile)
    }

    func testCancellationBeforeDemandDoesNotStartDownloadAndCancellationWhileRunningDropsLateCallbacks() throws {
        for starts in [false, true] {
            let session = DownloadSession()
            let subscriber = DownloadSubscriber()
            session.downloadTaskPublisher(for: URLRequest(url: url), progress: Progress(totalUnitCount: 1))
                .receive(subscriber: subscriber)
            if starts { subscriber.subscription?.request(.unlimited) }
            subscriber.subscription?.cancel()
            subscriber.subscription?.cancel()
            subscriber.subscription?.request(.unlimited)
            XCTAssertEqual(session.requests.count, starts ? 1 : 0)
            XCTAssertEqual(session.download.cancelCount, starts ? 1 : 0)
            let source = try temporaryDownload()
            defer { try? FileManager.default.removeItem(at: source) }
            session.complete(source, response(status: 200), nil)
            session.complete(nil, nil, URLError(.cancelled))
            XCTAssertTrue(subscriber.files.isEmpty)
            XCTAssertTrue(subscriber.completions.isEmpty)
            XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        }
    }

    func testProgressConsumesDemandAndFinalFileWaitsForDemand() throws {
        let session = DownloadSession()
        let progress = Progress(totalUnitCount: 1)
        let subscriber = DownloadSubscriber()
        session.downloadTaskPublisher(for: url, progress: progress).receive(subscriber: subscriber)
        subscriber.subscription?.request(.max(1))
        session.download.progress.completedUnitCount = 50
        XCTAssertEqual(subscriber.fractions.count, 1)
        XCTAssertEqual(subscriber.fractions[0], 0.5, accuracy: 0.001)
        let source = try temporaryDownload()
        session.complete(source, response(status: 200), nil)
        XCTAssertTrue(subscriber.files.isEmpty)
        XCTAssertTrue(subscriber.completions.isEmpty)
        subscriber.subscription?.request(.max(1))
        let saved = try XCTUnwrap(subscriber.files.first)
        defer { try? FileManager.default.removeItem(at: saved) }
        XCTAssertEqual(subscriber.completions.count, 1)
    }

    func testCancellationInsideValueCallbackPreventsFurtherDeliveryAndCompletion() throws {
        let session = DownloadSession()
        let subscriber = DownloadSubscriber()
        subscriber.onFile = { [weak subscriber] in subscriber?.subscription?.cancel() }
        session.downloadTaskPublisher(for: url, progress: Progress(totalUnitCount: 1))
            .receive(subscriber: subscriber)
        subscriber.subscription?.request(.unlimited)
        session.complete(try temporaryDownload(), response(status: 200), nil)
        let saved = try XCTUnwrap(subscriber.files.first)
        defer { try? FileManager.default.removeItem(at: saved) }
        XCTAssertTrue(subscriber.completions.isEmpty)
        session.complete(nil, nil, URLError(.timedOut))
        XCTAssertTrue(subscriber.completions.isEmpty)
    }

    func testTerminalAndCancelledSubscriptionsReleaseTheirSubscriber() {
        for cancelled in [false, true] {
            let session = DownloadSession()
            var subscriber: DownloadSubscriber? = DownloadSubscriber()
            weak var reference = subscriber
            session.downloadTaskPublisher(for: url, progress: Progress(totalUnitCount: 1))
                .receive(subscriber: subscriber!)
            let subscription = subscriber?.subscription
            subscription?.request(.unlimited)
            if cancelled { subscription?.cancel() } else { session.complete(nil, nil, URLError(.timedOut)) }
            subscriber = nil
            XCTAssertNil(reference)
            withExtendedLifetime(subscription) {}
        }
    }

    private func response(status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    private func temporaryDownload() throws -> URL {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1, 2, 3, 255]).write(to: file)
        return file
    }

    private func assertFailure(
        file: URL?, response: URLResponse?, error: Error?, expected: URLError.Code,
        line: UInt = #line
    ) {
        let session = DownloadSession()
        let subscriber = DownloadSubscriber()
        session.downloadTaskPublisher(for: url, progress: Progress(totalUnitCount: 1))
            .receive(subscriber: subscriber)
        subscriber.subscription?.request(.unlimited)
        session.complete(file, response, error)
        XCTAssertTrue(subscriber.files.isEmpty, line: line)
        XCTAssertEqual(subscriber.completions.count, 1, line: line)
        guard case .failure(let failure) = subscriber.completions.first else {
            return XCTFail("Expected download failure", line: line)
        }
        XCTAssertEqual(failure.code, expected, line: line)
    }
}

private final class DownloadSession: URLSession, @unchecked Sendable {
    let download = DownloadTask()
    var requests: [URLRequest] = []
    private var completion: (@Sendable (URL?, URLResponse?, Error?) -> Void)?
    override func downloadTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (URL?, URLResponse?, Error?) -> Void
    ) -> URLSessionDownloadTask {
        requests.append(request)
        completion = completionHandler
        return download
    }
    func complete(_ file: URL?, _ response: URLResponse?, _ error: Error?) { completion?(file, response, error) }
}

private final class DownloadTask: URLSessionDownloadTask, @unchecked Sendable {
    private let downloadProgress = Progress(totalUnitCount: 100)
    override var progress: Progress { downloadProgress }
    var resumeCount = 0
    var cancelCount = 0
    override func resume() { resumeCount += 1 }
    override func cancel() { cancelCount += 1 }
}

private final class DownloadSubscriber: Subscriber {
    typealias Input = DownloadResponse
    typealias Failure = URLError
    var subscription: Subscription?
    var files: [URL] = []
    var fractions: [Double] = []
    var completions: [Subscribers.Completion<URLError>] = []
    var onFile: (() -> Void)?
    func receive(subscription: Subscription) { self.subscription = subscription }
    func receive(_ input: DownloadResponse) -> Subscribers.Demand {
        switch input {
        case .progress(let progress): fractions.append(progress.fractionCompleted)
        case .response(let url): files.append(url); onFile?()
        }
        return .none
    }
    func receive(completion: Subscribers.Completion<URLError>) { completions.append(completion) }
}
