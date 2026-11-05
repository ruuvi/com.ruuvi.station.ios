import Combine
import Foundation
@testable import RuuviDFU
#if SWIFT_PACKAGE
    @testable import RuuviDFUImpl
#endif
#if canImport(NordicDFU)
    import NordicDFU
#endif
#if canImport(iOSDFULibrary)
    import iOSDFULibrary
#endif
import XCTest

@MainActor final class FlasherTests: XCTestCase {
    func testFilesWaitForSubscriptionUploadInOrderAndReportWeightedBoundedProgress() async throws {
        let fixture = try FlashFixture()
        let first = try fixture.file("application.bin", bytes: 10)
        let second = try fixture.file("filesystem.bin", bytes: 30)
        let publisher = fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: [first, second])
        fixture.flush()
        XCTAssertEqual(fixture.createdTransports, 0)
        let capture = fixture.subscribe(publisher)
        try await fixture.wait { fixture.transport.uploads.count == 1 }
        fixture.queue.sync {
            let upload = fixture.transport.uploads[0]
            XCTAssertEqual(upload.path, "/lfs1/application.bin")
            XCTAssertEqual(upload.data.count, 10)
            upload.progress(5)
            upload.progress(-1)
            upload.progress(Int.max)
            upload.completion(.success(()))
            upload.completion(.success(()))
        }
        try await fixture.wait { fixture.transport.uploads.count == 2 }
        fixture.queue.sync {
            let second = fixture.transport.uploads[1]
            XCTAssertEqual(second.path, "/lfs1/filesystem.bin")
            XCTAssertEqual(second.data.count, 30)
            second.progress(15)
            fixture.transport.uploads[0].progress(1000)
            fixture.transport.uploads[0].completion(.failure(FlashTestError.failed))
            second.completion(.success(()))
        }
        try await fixture.wait { fixture.transport.resets.count == 1 }
        XCTAssertEqual(capture.done, 0, "Upload completion alone does not confirm a reboot")
        fixture.queue.sync { fixture.transport.resets[0](nil) }
        try await fixture.wait { capture.finished == 1 }
        XCTAssertEqual(capture.done, 1)
        XCTAssertTrue(capture.errors.isEmpty)
        XCTAssertTrue(capture.progress.contains(0.125))
        XCTAssertTrue(capture.progress.contains(0.625))
        XCTAssertEqual(capture.progress.last, 1)
        XCTAssertEqual(capture.progress, capture.progress.sorted())
        XCTAssertTrue(capture.progress.allSatisfy { (0...1).contains($0) })
    }

    func testInvalidFileBatchesFailBeforeCreatingBluetoothTransport() async throws {
        let fixture = try FlashFixture()
        let valid = try fixture.file("valid.bin", bytes: 10)
        let empty = try fixture.file("empty.bin", bytes: 0)
        let missing = fixture.directory.appendingPathComponent("missing.bin")
        for urls in [[], [missing], [valid, missing], [empty]] {
            let capture = fixture.subscribe(fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: urls))
            try await fixture.wait { capture.errors.count == 1 }
            XCTAssertEqual(capture.done, 0)
            XCTAssertEqual(fixture.createdTransports, 0)
        }
    }

    func testSynchronousTransportFailureAndCompletionAreDeliveredToTheSubscriber() async throws {
        let fixture = try FlashFixture()
        let file = try fixture.file("app.bin", bytes: 10)
        fixture.transport.starts = false
        let failure = fixture.subscribe(fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: file))
        try await fixture.wait { failure.errors.count == 1 }
        XCTAssertEqual(failure.done, 0)
        fixture.queue.sync {
            fixture.transport.starts = true
            fixture.transport.synchronousCompletion = true
            fixture.transport.synchronousReset = true
        }
        let success = fixture.subscribe(fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: file))
        try await fixture.wait { success.finished == 1 }
        XCTAssertEqual(success.done, 1)
        XCTAssertEqual(success.progress.last, 1)
    }

    func testResetFailureDoesNotReportUpgradeSuccessAndAllowsRetry() async throws {
        let fixture = try FlashFixture()
        let file = try fixture.file("app.bin", bytes: 10)
        fixture.transport.synchronousCompletion = true
        let capture = fixture.subscribe(fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: file))
        try await fixture.wait { fixture.transport.resets.count == 1 }
        fixture.queue.sync { fixture.transport.resets[0](FlashTestError.failed) }
        try await fixture.wait { capture.errors.count == 1 }
        XCTAssertEqual(capture.done, 0)
        XCTAssertEqual(capture.finished, 0)
        fixture.queue.sync { fixture.transport.synchronousReset = true }
        let retry = fixture.subscribe(fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: file))
        try await fixture.wait { retry.finished == 1 }
        XCTAssertEqual(retry.done, 1)
    }

    func testCancellingMatchingDeviceIgnoresStaleFileCallbacksAndAllowsANewUpgrade() async throws {
        let fixture = try FlashFixture()
        let file = try fixture.file("app.bin", bytes: 10)
        let first = fixture.subscribe(fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: file))
        try await fixture.wait { fixture.transport.uploads.count == 1 }
        let unrelated = DFUDevice(
            uuid: UUID().uuidString, rssi: -50, isConnectable: true, name: nil,
            peripheral: TestDFUPeripheral())
        XCTAssertFalse(fixture.flasher.stopFlashFirmware(device: unrelated))
        XCTAssertTrue(fixture.flasher.stopFlashFirmware(device: fixture.device))
        XCTAssertEqual(first.errors.count, 1)
        XCTAssertFalse(fixture.flasher.stopFlashFirmware(device: fixture.device))
        let second = fixture.subscribe(fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: file))
        try await fixture.wait { fixture.transport.uploads.count == 2 }
        fixture.queue.sync {
            fixture.transport.uploads[0].progress(10)
            fixture.transport.uploads[0].completion(.success(()))
            fixture.transport.uploads[0].completion(.failure(FlashTestError.failed))
        }
        fixture.flush()
        XCTAssertEqual(second.done, 0)
        XCTAssertTrue(second.errors.isEmpty)
        XCTAssertTrue(second.progress.isEmpty)
        XCTAssertEqual(fixture.transport.resets.count, 0)
        XCTAssertTrue(fixture.flasher.stopFlashFirmware(device: fixture.device))
        XCTAssertEqual(fixture.transport.cancels, 2)
    }

    func testConcurrentUpgradeIsRejectedWithoutReplacingTheActiveSubscriber() async throws {
        let fixture = try FlashFixture()
        let file = try fixture.file("app.bin", bytes: 10)
        let first = fixture.subscribe(fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: file))
        try await fixture.wait { fixture.transport.uploads.count == 1 }
        let second = fixture.subscribe(fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: file))
        try await fixture.wait { second.errors.count == 1 }
        XCTAssertTrue(first.errors.isEmpty)
        XCTAssertEqual(fixture.transport.uploads.count, 1)
        first.token?.cancel()
        fixture.flush()
        XCTAssertEqual(fixture.transport.cancels, 1)
        let retry = fixture.subscribe(fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: file))
        try await fixture.wait { fixture.transport.uploads.count == 2 }
        XCTAssertTrue(retry.errors.isEmpty)
    }

    func testFileFailureStopsTheBatchAndTransportConstructionErrorsReachCaller() async throws {
        let fixture = try FlashFixture()
        let file = try fixture.file("app.bin", bytes: 10)
        let first = fixture.subscribe(fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: [file, file]))
        try await fixture.wait { fixture.transport.uploads.count == 1 }
        fixture.queue.sync { fixture.transport.uploads[0].completion(.failure(FlashTestError.failed)) }
        try await fixture.wait { first.errors.count == 1 }
        XCTAssertEqual(fixture.transport.uploads.count, 1)
        XCTAssertTrue(fixture.transport.resets.isEmpty)
        fixture.factoryFails = true
        let second = fixture.subscribe(fixture.flasher.flashFirmware(dfuDevice: fixture.device, with: file))
        try await fixture.wait { second.errors.count == 1 }
        XCTAssertEqual(second.done, 0)
    }

    func testLegacyValidationImmediateFailureProgressLogsAndCompletion() async throws {
        let fixture = try FlashFixture()
        let firmware = DFUFirmware(binFile: Data([1, 2, 3]), datFile: nil, type: .application)
        let invalid = fixture.subscribe(fixture.flasher.flashFirmware(uuid: "bad", with: firmware))
        try await fixture.wait { invalid.errors.count == 1 }
        XCTAssertEqual(fixture.legacy.starts, 0)
        fixture.legacy.canStart = false
        let rejected = fixture.subscribe(fixture.flasher.flashFirmware(uuid: fixture.device.uuid, with: firmware))
        try await fixture.wait { rejected.errors.count == 1 }
        fixture.queue.sync { fixture.legacy.canStart = true }
        let success = fixture.subscribe(fixture.flasher.flashFirmware(uuid: fixture.device.uuid, with: firmware))
        try await fixture.wait { fixture.legacy.starts == 2 }
        fixture.queue.sync {
            fixture.legacy.event?(.progress(0.5))
            fixture.legacy.event?(.progress(0.1))
            fixture.legacy.event?(.progress(.nan))
            fixture.legacy.event?(.progress(2))
            fixture.legacy.event?(.log(.init(message: "Uploading", time: Date(timeIntervalSince1970: 10))))
            fixture.legacy.event?(.done)
            fixture.legacy.completion?(.success(()))
        }
        try await fixture.wait { success.finished == 1 }
        XCTAssertEqual(success.done, 1)
        XCTAssertEqual(success.logs.map(\.message), ["Uploading"])
        XCTAssertEqual(success.progress, [0.5, 0.5, 1, 1])
    }

    func testLegacyAbortFailureAndErrorDoNotLeaveTheFlasherBusy() async throws {
        let fixture = try FlashFixture()
        let firmware = DFUFirmware(binFile: Data([1]), datFile: nil, type: .application)
        let capture = fixture.subscribe(fixture.flasher.flashFirmware(uuid: fixture.device.uuid, with: firmware))
        try await fixture.wait { fixture.legacy.starts == 1 }
        fixture.queue.sync { fixture.legacy.canCancel = false }
        XCTAssertFalse(fixture.flasher.stopFlashFirmware(device: fixture.device))
        XCTAssertTrue(capture.errors.isEmpty)
        fixture.queue.sync { fixture.legacy.completion?(.failure(FlashTestError.failed)) }
        try await fixture.wait { capture.errors.count == 1 }
        let retry = fixture.subscribe(fixture.flasher.flashFirmware(uuid: fixture.device.uuid, with: firmware))
        try await fixture.wait { fixture.legacy.starts == 2 }
        fixture.queue.sync { fixture.legacy.canCancel = true }
        XCTAssertTrue(fixture.flasher.stopFlashFirmware(device: fixture.device))
        XCTAssertEqual(retry.errors.count, 1)
    }

    func testNativeDelegatesCompleteOnceAndMultipartProgressDoesNotDoubleCount() throws {
        var progress: [Int] = []
        var results: [Result<Void, Error>] = []
        let delegate = DFUUploadDelegate(progress: { progress.append($0) }, completion: { results.append($0) })
        delegate.uploadProgressDidChange(bytesSent: 5, fileSize: 10, timestamp: Date())
        delegate.uploadDidFinish()
        delegate.uploadDidFinish()
        delegate.uploadDidCancel()
        delegate.uploadDidFail(with: FlashTestError.failed)
        delegate.uploadProgressDidChange(bytesSent: 10, fileSize: 10, timestamp: Date())
        XCTAssertEqual(progress, [5])
        XCTAssertEqual(results.count, 1)
        XCTAssertNoThrow(try results[0].get())
        for cancel in [true, false] {
            let failing = DFUUploadDelegate(progress: { _ in }, completion: { results.append($0) })
            if cancel { failing.uploadDidCancel() } else { failing.uploadDidFail(with: FlashTestError.failed) }
            XCTAssertThrowsError(try results.last!.get())
        }
        let legacy = DFUNordicTransport(queue: DispatchQueue(label: "legacy-delegate"))
        let capture = FlashCapture()
        legacy.event = capture.receive
        legacy.completion = { results.append($0) }
        for (part, total, value) in [(0, 0, 1), (1, 2, 100), (1, 2, 100), (2, 2, 25), (2, 2, 100)] {
            legacy.dfuProgressDidChange(
                for: part, outOf: total, to: value,
                currentSpeedBytesPerSecond: 0, avgSpeedBytesPerSecond: 0)
        }
        XCTAssertEqual(capture.progress, [0.5, 0.5, 0.625, 1])
        legacy.logWith(.info, message: "Connected")
        XCTAssertEqual(capture.logs.first?.message, "Connected")
        legacy.dfuStateDidChange(to: .connecting)
        legacy.dfuStateDidChange(to: .completed)
        legacy.dfuStateDidChange(to: .completed)
        XCTAssertEqual(results.count, 4)
        legacy.completion = { results.append($0) }
        legacy.dfuStateDidChange(to: .aborted)
        XCTAssertThrowsError(try results.last!.get())
        legacy.completion = { results.append($0) }
        legacy.dfuError(.fileInvalid, didOccurWithMessage: "Transfer failed")
        XCTAssertThrowsError(try results.last!.get())
        XCTAssertFalse(legacy.cancel())
    }

    func testCancellingSubscriberReleasesLegacySessionEvenWhenTransportCannotAbort() async throws {
        let fixture = try FlashFixture()
        let firmware = DFUFirmware(binFile: Data([1]), datFile: nil, type: .application)
        let first = fixture.subscribe(fixture.flasher.flashFirmware(uuid: fixture.device.uuid, with: firmware))
        try await fixture.wait { fixture.legacy.starts == 1 }
        fixture.queue.sync { fixture.legacy.canCancel = false }
        first.token?.cancel()
        fixture.flush()
        let second = fixture.subscribe(fixture.flasher.flashFirmware(uuid: fixture.device.uuid, with: firmware))
        try await fixture.wait { fixture.legacy.starts == 2 }
        XCTAssertTrue(second.errors.isEmpty)
        second.token?.cancel()
        fixture.flush()
    }

    func testFirmwareOwnerReleaseCompletesActiveSubscriberAndUnstartedPublisher() async throws {
        let queue = DispatchQueue(label: "release-firmware")
        let legacy = LegacyTransportSpy()
        let firmware = DFUFirmware(binFile: Data([1]), datFile: nil, type: .application)
        var flasher: DfuFlasher? = DfuFlasher(queue: queue, legacyFactory: { legacy })
        let publisher = flasher!.flashFirmware(uuid: UUID().uuidString, with: firmware)
        weak var weakFlasher = flasher
        let finished = expectation(description: "Owner release fails active operation")
        let token = publisher.sink(
            receiveCompletion: { completion in
                if case .failure = completion { finished.fulfill() }
            }, receiveValue: { _ in })
        queue.sync {}
        flasher = nil
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertNil(weakFlasher)
        var failures = 0
        let late = publisher.sink(
            receiveCompletion: { if case .failure = $0 { failures += 1 } },
            receiveValue: { _ in XCTFail("Released owner cannot upload") })
        XCTAssertEqual(failures, 1)
        withExtendedLifetime((token, late)) {}
    }

    func testHardwareTransportRejectsAnUnavailablePeripheralWithoutStartingBluetooth() throws {
        let fixture = try FlashFixture()
        XCTAssertThrowsError(try DFUMcuTransport(device: fixture.device))
    }
}

private enum FlashTestError: Error { case failed }
private final class FlashCapture {
    var token: AnyCancellable?
    var progress: [Double] = []
    var logs: [DFULog] = []
    var done = 0
    var finished = 0
    var errors: [Error] = []
    func receive(_ event: FlashResponse) {
        switch event {
        case .progress(let value): progress.append(value)
        case .log(let log): logs.append(log)
        case .done: done += 1
        }
    }
}

private final class FlashFixture {
    let queue = DispatchQueue(label: "flash-tests")
    let transport = FileTransportSpy()
    let legacy = LegacyTransportSpy()
    let directory: URL
    let device: DFUDevice
    var createdTransports = 0
    var factoryFails = false
    var captures: [FlashCapture] = []
    lazy var flasher = DfuFlasher(
        queue: queue, legacyFactory: { [legacy] in legacy },
        transportFactory: { [unowned self] _ in
            self.createdTransports += 1
            if self.factoryFails { throw FlashTestError.failed }
            return self.transport
        }, partition: { "/lfs1/" }, nextUploadDelay: 0)
    init() throws {
        let peripheral = TestDFUPeripheral()
        device = DFUDevice(
            uuid: peripheral.identifier.uuidString, rssi: -50, isConnectable: true, name: "Test",
            peripheral: peripheral)
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: directory) }
    func file(_ name: String, bytes: Int) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(repeating: 42, count: bytes).write(to: url)
        return url
    }
    func subscribe(_ publisher: AnyPublisher<FlashResponse, Error>) -> FlashCapture {
        let capture = FlashCapture()
        capture.token = publisher.sink(
            receiveCompletion: { [weak capture] completion in
                switch completion {
                case .finished: capture?.finished += 1
                case .failure(let error): capture?.errors.append(error)
                }
            }, receiveValue: { [weak capture] in capture?.receive($0) })
        captures.append(capture)
        return capture
    }
    func flush() { queue.sync {} }
    func wait(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<100 {
            if queue.sync(execute: condition) { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for firmware operation", file: file, line: line)
    }
}

private final class FileTransportSpy: DFUFileTransport {
    struct Upload {
        let path: String
        let data: Data
        let progress: (Int) -> Void
        let completion: (Result<Void, Error>) -> Void
    }
    var starts = true
    var synchronousCompletion = false
    var synchronousReset = false
    var uploads: [Upload] = []
    var resets: [(Error?) -> Void] = []
    var cancels = 0
    func upload(
        path: String, data: Data, progress: @escaping (Int) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Bool {
        uploads.append(Upload(path: path, data: data, progress: progress, completion: completion))
        if synchronousCompletion { progress(data.count); completion(.success(())) }
        return starts
    }
    func reset(completion: @escaping (Error?) -> Void) {
        resets.append(completion)
        if synchronousReset { completion(nil) }
    }
    func cancel() { cancels += 1 }
}

private final class LegacyTransportSpy: DFULegacyFlashing {
    var starts = 0
    var canStart = true
    var canCancel = true
    var event: ((FlashResponse) -> Void)?
    var completion: ((Result<Void, Error>) -> Void)?
    func start(
        uuid: UUID, firmware: DFUFirmware, event: @escaping (FlashResponse) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Bool {
        starts += 1
        self.event = event
        self.completion = completion
        return canStart
    }
    func cancel() -> Bool { canCancel }
}
