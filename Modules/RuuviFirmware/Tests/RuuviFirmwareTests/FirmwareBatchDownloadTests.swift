import Combine
import Foundation
@testable import RuuviFirmware
import XCTest

final class FirmwareBatchDownloadTests: XCTestCase {
    func testSynchronousDownloadsAreLazyRepeatableAndPreserveAssetOrder() {
        let repository = BatchRepository()
        var requests: [URL] = []
        let downloader = FirmwareDownloader(repository: repository) { url, progress in
            requests.append(url)
            return [.progress(progress), .response(fileUrl: url)].publisher
                .setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        let assets = assets()
        let publisher = downloader.download(assets: assets)
        XCTAssertTrue(requests.isEmpty)
        for _ in 0..<2 {
            var files: [[URL]] = []
            var progressEvents = 0
            var completed = false
            let token = publisher.sink(
                receiveCompletion: {
                    if case .failure(let error) = $0 { XCTFail("Unexpected \(error)") }
                    completed = true
                },
                receiveValue: {
                    switch $0 {
                    case .progress(let progress):
                        XCTAssertEqual(progress.totalUnitCount, 3)
                        progressEvents += 1
                    case .files(let result): files.append(result)
                    }
                })
            XCTAssertTrue(completed)
            XCTAssertEqual(progressEvents, 3)
            XCTAssertEqual(files, [assets.map { URL(fileURLWithPath: "/saved/" + $0.name) }])
            withExtendedLifetime(token) {}
        }
        XCTAssertEqual(requests, (assets + assets).map(\.url))
        XCTAssertEqual(repository.savedNames, (assets + assets).map(\.name))
    }

    func testOutOfOrderCompletionStillReturnsPrimaryFirstAndOnlyOneCompleteBatch() {
        let subjects = (0..<3).map { _ in PassthroughSubject<DownloadResponse, Error>() }
        var next = 0
        let downloader = FirmwareDownloader(repository: BatchRepository()) { _, _ in
            defer { next += 1 }
            return subjects[next].eraseToAnyPublisher()
        }
        var files: [[URL]] = []
        var completed = false
        let token = downloader.download(assets: assets()).sink(
            receiveCompletion: { _ in completed = true },
            receiveValue: {
                if case .files(let urls) = $0 { files.append(urls) }
            })
        for index in [2, 0, 1] {
            subjects[index].send(.response(fileUrl: URL(fileURLWithPath: "/download/\(index)")))
            if index != 1 { XCTAssertTrue(files.isEmpty) }
            subjects[index].send(completion: .finished)
        }
        XCTAssertEqual(files, [assets().map { URL(fileURLWithPath: "/saved/" + $0.name) }])
        XCTAssertTrue(completed)
        withExtendedLifetime(token) {}
    }

    func testCancellingOneSubscriptionDoesNotCancelAnotherBatch() {
        var subjects: [PassthroughSubject<DownloadResponse, Error>] = []
        var cancellations: [Int] = []
        let downloader = FirmwareDownloader(repository: BatchRepository()) { _, _ in
            let index = subjects.count
            let subject = PassthroughSubject<DownloadResponse, Error>()
            subjects.append(subject)
            return subject.handleEvents(receiveCancel: { cancellations.append(index) }).eraseToAnyPublisher()
        }
        var firstValues = 0
        var secondFiles: [URL] = []
        let publisher = downloader.download(assets: Array(assets().prefix(1)))
        let first = publisher.sink(
            receiveCompletion: { _ in XCTFail("Cancelled batch completed") },
            receiveValue: { _ in
                firstValues += 1
            })
        let second = publisher.sink(
            receiveCompletion: {
                if case .failure(let error) = $0 { XCTFail("Unexpected \(error)") }
            }, receiveValue: { if case .files(let urls) = $0 { secondFiles = urls } })
        first.cancel()
        XCTAssertEqual(cancellations, [0])
        subjects[0].send(.response(fileUrl: URL(fileURLWithPath: "/cancelled")))
        subjects[1].send(.response(fileUrl: URL(fileURLWithPath: "/success")))
        subjects[1].send(completion: .finished)
        XCTAssertEqual(firstValues, 0)
        XCTAssertEqual(secondFiles, [URL(fileURLWithPath: "/saved/primary.bin")])
        withExtendedLifetime(second) {}
    }

    func testInvalidAssetURLsFailBeforeAnyNetworkRequest() {
        var requests = 0
        let downloader = FirmwareDownloader(repository: BatchRepository()) { _, _ in
            requests += 1
            return Empty().eraseToAnyPublisher()
        }
        let invalid: [[FirmwareDownloadAsset]] = [
            [],
            [.init(name: "firmware", url: URL(fileURLWithPath: "/file"))],
            [.init(name: "firmware", url: URL(string: "relative/file")!)],
            [.init(name: "firmware", url: URL(string: "ftp://example.com/file")!)],
        ]
        for assets in invalid {
            var error: Error?
            let token = downloader.download(assets: assets).sink(
                receiveCompletion: {
                    if case .failure(let failure) = $0 { error = failure }
                }, receiveValue: { _ in XCTFail("Invalid assets produced a value") })
            XCTAssertEqual((error as? URLError)?.code, .badURL)
            withExtendedLifetime(token) {}
        }
        XCTAssertEqual(requests, 0)
    }

    func testMissingFileTransportFailureAndRepositoryFailureAreDeliveredToSubscriber() {
        for scenario in 0..<3 {
            let repository = BatchRepository()
            repository.fail = scenario == 2
            let downloader = FirmwareDownloader(repository: repository) { _, _ in
                switch scenario {
                case 0: return Empty().eraseToAnyPublisher()
                case 1: return Fail(error: URLError(.timedOut) as Error).eraseToAnyPublisher()
                default:
                    return Just(.response(fileUrl: URL(fileURLWithPath: "/download")))
                        .setFailureType(to: Error.self).eraseToAnyPublisher()
                }
            }
            var error: Error?
            let token = downloader.download(assets: assets()).sink(
                receiveCompletion: {
                    if case .failure(let failure) = $0 { error = failure }
                }, receiveValue: { _ in XCTFail("Failed download must not produce firmware") })
            XCTAssertEqual((error as? URLError)?.code, [.badServerResponse, .timedOut, .cannotWriteToFile][scenario])
            withExtendedLifetime(token) {}
        }
    }

    func testOneDownloadFailureCancelsAllRemainingAssets() {
        let subjects = (0..<3).map { _ in PassthroughSubject<DownloadResponse, Error>() }
        var next = 0
        var cancellations: [Int] = []
        let downloader = FirmwareDownloader(repository: BatchRepository()) { _, _ in
            let index = next
            next += 1
            return subjects[index].handleEvents(receiveCancel: { cancellations.append(index) }).eraseToAnyPublisher()
        }
        var errors: [Error] = []
        let token = downloader.download(assets: assets()).sink(
            receiveCompletion: {
                if case .failure(let error) = $0 { errors.append(error) }
            }, receiveValue: { _ in XCTFail("Incomplete batch produced files") })
        subjects[1].send(completion: .failure(URLError(.networkConnectionLost)))
        XCTAssertEqual(errors.count, 1)
        XCTAssertEqual((errors.first as? URLError)?.code, .networkConnectionLost)
        XCTAssertTrue(cancellations.contains(0))
        XCTAssertTrue(cancellations.contains(2))
        withExtendedLifetime(token) {}
    }

    private func assets() -> [FirmwareDownloadAsset] {
        ["primary.bin", "loader.bin", "boot.bin"].map {
            .init(name: $0, url: URL(string: "https://example.com/" + $0)!)
        }
    }
}

private final class BatchRepository: FirmwareRepository {
    var savedNames: [String] = []
    var fail = false
    func save(name: String, fileUrl: URL) throws -> URL {
        if fail { throw URLError(.cannotWriteToFile) }
        savedNames.append(name)
        return URL(fileURLWithPath: "/saved/" + name)
    }
}
