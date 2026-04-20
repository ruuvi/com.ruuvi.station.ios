@testable import RuuviDFU
import Combine
import CoreBluetooth
import Foundation
import iOSMcuManagerLibrary
import NordicDFU
import XCTest

final class RuuviDFUTests: XCTestCase {
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "partition_key")
    }

    override func tearDown() {
        cancellables.removeAll()
        UserDefaults.standard.removeObject(forKey: "partition_key")
        super.tearDown()
    }

    func testTokenInvalidateRunsCancellationClosure() {
        var invalidationCount = 0
        let token = RuuviDFUToken {
            invalidationCount += 1
        }

        token.invalidate()
        token.invalidate()

        XCTAssertEqual(invalidationCount, 2)
    }

    func testDFULogStoresMessageAndTime() {
        let now = Date()
        let log = DFULog(message: "Flashing started", time: now)

        XCTAssertEqual(log.message, "Flashing started")
        XCTAssertEqual(log.time, now)
    }

    func testDfuErrorStoresDescription() {
        let error = RuuviDfuError(description: "Firmware missing")

        XCTAssertEqual(error.description, "Firmware missing")
    }

    func testFirmwareTypesExposeExpectedCases() {
        XCTAssertEqual(RuuviDFUFirmwareType.allCases, [.latest, .alpha, .beta])
    }

    func testDFUDeviceEqualityUsesUUIDOnly() {
        let sharedUUID = "same-device"
        let lhs = DFUDevice(
            uuid: sharedUUID,
            rssi: -40,
            isConnectable: true,
            name: "Left",
            peripheral: unsafeBitCast(FakePeripheral(), to: CBPeripheral.self)
        )
        let rhs = DFUDevice(
            uuid: sharedUUID,
            rssi: -90,
            isConnectable: false,
            name: "Right",
            peripheral: unsafeBitCast(FakePeripheral(), to: CBPeripheral.self)
        )
        let other = makeDevice(uuid: "different-device")

        XCTAssertEqual(lhs, rhs)
        XCTAssertNotEqual(lhs, other)
        XCTAssertEqual(Set([lhs, rhs, other]).count, 2)
    }

    func testDFUImplDelegatesScanLostFlashAndStopToInjectedCollaborators() {
        let scanner = ScannerSpy()
        let flasher = FlasherSpy()
        let sut = RuuviDFUImpl(scanner: scanner, flasher: flasher)
        let observer = DummyObserver()
        let expectedToken = RuuviDFUToken {}
        let firmware = makeDummyFirmware()
        let device = makeDevice()
        let urls = [
            URL(fileURLWithPath: "/tmp/firmware-a.bin"),
            URL(fileURLWithPath: "/tmp/firmware-b.bin"),
        ]
        scanner.tokenToReturn = expectedToken
        flasher.stopResult = true

        let scanToken = sut.scan(observer, includeScanServices: false) { _, _ in }
        let lostToken = sut.lost(observer) { _, _ in }
        _ = sut.flashFirmware(uuid: device.uuid, with: firmware)
        _ = sut.flashFirmware(dfuDevice: device, with: urls)
        let stopResult = sut.stopFlashFirmware(device: device)

        XCTAssertTrue(scanToken === expectedToken)
        XCTAssertTrue(lostToken === expectedToken)
        XCTAssertEqual(scanner.includeScanServicesValues, [false])
        XCTAssertEqual(scanner.scanCallCount, 1)
        XCTAssertEqual(scanner.lostCallCount, 1)
        XCTAssertEqual(flasher.legacyFlashCalls.first?.uuid, device.uuid)
        XCTAssertEqual(flasher.fileFlashCalls.first?.urls, urls)
        XCTAssertTrue(stopResult)
        XCTAssertEqual(flasher.stopCalls.count, 1)
    }

    func testDFUImplSingleFileOverloadDelegatesToFlasher() {
        let flasher = FlasherSpy()
        let sut = RuuviDFUImpl(scanner: ScannerSpy(), flasher: flasher)
        let device = makeDevice(uuid: "single-file-device")
        let url = URL(fileURLWithPath: "/tmp/firmware.bin")

        _ = sut.flashFirmware(dfuDevice: device, with: url)

        XCTAssertEqual(flasher.fileFlashCalls.count, 1)
        XCTAssertEqual(flasher.fileFlashCalls.first?.device.uuid, "single-file-device")
        XCTAssertEqual(flasher.fileFlashCalls.first?.urls, [url])
    }

    func testDFUImplReturnsNilFirmwareForMissingZip() {
        let sut = RuuviDFUImpl()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

        XCTAssertNil(sut.firmwareFromUrl(url: url))
    }

    func testDfuProtocolExtensionDelegatesFirstFirmwareURLToSingleFileOverload() {
        let sut = DfuProtocolSpy()
        let device = makeDevice()
        let urls = [
            URL(fileURLWithPath: "/tmp/first.bin"),
            URL(fileURLWithPath: "/tmp/second.bin"),
        ]

        _ = sut.flashFirmware(dfuDevice: device, with: urls)

        XCTAssertEqual(sut.singleFileRequests.count, 1)
        XCTAssertEqual(sut.singleFileRequests.first?.device.uuid, device.uuid)
        XCTAssertEqual(sut.singleFileRequests.first?.url, urls[0])
    }

    func testDfuProtocolExtensionFailsForEmptyFirmwareURLArray() {
        let sut = DfuProtocolSpy()
        let completion = expectation(description: "empty firmware urls failure")
        var receivedError: RuuviDfuError?

        sut.flashFirmware(dfuDevice: makeDevice(), with: [])
            .sink(receiveCompletion: { result in
                guard case let .failure(error) = result else {
                    return XCTFail("Expected failure completion")
                }
                receivedError = error as? RuuviDfuError
                completion.fulfill()
            }, receiveValue: { _ in
                XCTFail("Unexpected firmware response")
            })
            .store(in: &cancellables)

        wait(for: [completion], timeout: 1)
        XCTAssertEqual(receivedError?.description, "No firmware files provided")
        XCTAssertTrue(sut.singleFileRequests.isEmpty)
    }

    func testFlasherReturnsFailureForInvalidLegacyUUID() {
        let sut = makeFlasher()
        let expectation = expectation(description: "invalid uuid failure")
        var receivedError: RuuviDfuError?

        sut.flashFirmware(uuid: "not-a-uuid", with: makeDummyFirmware())
            .sink(receiveCompletion: { completion in
                guard case let .failure(error) = completion else {
                    return XCTFail("Expected failure completion")
                }
                receivedError = error as? RuuviDfuError
                expectation.fulfill()
            }, receiveValue: { _ in
                XCTFail("Unexpected flash value")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedError?.description, "Invalid UUID")
    }

    func testFlasherDefaultInitializerConstructs() {
        let sut = DfuFlasher()

        XCTAssertNotNil(sut)
    }

    func testFlasherSingleFileUploadDelegatesToArrayOverload() {
        let sut = FlasherSpy()
        let device = makeDevice()
        let url = URL(fileURLWithPath: "/tmp/firmware.bin")

        _ = sut.flashFirmware(dfuDevice: device, with: url)

        XCTAssertEqual(sut.fileFlashCalls.count, 1)
        XCTAssertEqual(sut.fileFlashCalls.first?.device.uuid, device.uuid)
        XCTAssertEqual(sut.fileFlashCalls.first?.urls, [url])
    }

    func testFlasherStartsLegacyDFUEmitsProgressAndCompletes() {
        let controller = ServiceControllerSpy()
        let legacyStarter = LegacyStarterSpy(controller: controller)
        let sut = makeFlasher(legacyStarter: legacyStarter)
        let expectation = expectation(description: "legacy flash completion")
        var progressValues: [Double] = []
        var didFinish = false

        sut.flashFirmware(
            uuid: "CB9FE4D2-19B4-4A78-8A4F-477D64FB1FE6",
            with: makeDummyFirmware()
        )
        .sink(receiveCompletion: { completion in
            guard case .finished = completion else {
                return XCTFail("Expected finished completion")
            }
            didFinish = true
            expectation.fulfill()
        }, receiveValue: { response in
            switch response {
            case let .progress(value):
                progressValues.append(value)
            case .done:
                progressValues.append(1.0)
            case .log:
                break
            }
        })
        .store(in: &cancellables)

        XCTAssertTrue(legacyStarter.delegate === sut)
        XCTAssertTrue(legacyStarter.progressDelegate === sut)
        XCTAssertTrue(legacyStarter.logger === sut)
        XCTAssertEqual(
            legacyStarter.startedUUIDs,
            [UUID(uuidString: "CB9FE4D2-19B4-4A78-8A4F-477D64FB1FE6")]
        )

        sut.dfuProgressDidChange(
            for: 1,
            outOf: 1,
            to: 50,
            currentSpeedBytesPerSecond: 0,
            avgSpeedBytesPerSecond: 0
        )
        sut.dfuStateDidChange(to: .completed)

        wait(for: [expectation], timeout: 1)
        XCTAssertTrue(didFinish)
        XCTAssertEqual(progressValues.first ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(controller.abortCalls, 0)
    }

    func testFlasherLegacyProgressTracksCompletedParts() {
        let sut = makeFlasher(legacyStarter: LegacyStarterSpy())
        let completion = expectation(description: "legacy progress received")
        completion.expectedFulfillmentCount = 2
        var progressValues: [Double] = []
        let firmware = DFUFirmware(
            binFile: Data([0x01, 0x02]),
            datFile: Data([0x03]),
            type: .application
        )

        sut.flashFirmware(
            uuid: "CB9FE4D2-19B4-4A78-8A4F-477D64FB1FE6",
            with: firmware
        )
        .sink(receiveCompletion: { _ in
        }, receiveValue: { response in
            guard case let .progress(value) = response else {
                return
            }
            progressValues.append(value)
            completion.fulfill()
        })
        .store(in: &cancellables)

        sut.dfuProgressDidChange(
            for: 1,
            outOf: 2,
            to: 100,
            currentSpeedBytesPerSecond: 0,
            avgSpeedBytesPerSecond: 0
        )
        sut.dfuProgressDidChange(
            for: 2,
            outOf: 2,
            to: 50,
            currentSpeedBytesPerSecond: 0,
            avgSpeedBytesPerSecond: 0
        )

        wait(for: [completion], timeout: 1)
        XCTAssertEqual(progressValues.first ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(progressValues.last ?? 0, 1.5, accuracy: 0.0001)
    }

    func testFlasherLegacyErrorAndLogsPublishExpectedResponses() {
        let sut = makeFlasher(legacyStarter: LegacyStarterSpy())
        let logExpectation = expectation(description: "legacy log received")
        let completion = expectation(description: "legacy error completion")
        var loggedMessages: [String] = []
        var receivedError: RuuviDfuError?

        sut.flashFirmware(
            uuid: "CB9FE4D2-19B4-4A78-8A4F-477D64FB1FE6",
            with: makeDummyFirmware()
        )
        .sink(receiveCompletion: { result in
            guard case let .failure(error) = result else {
                return XCTFail("Expected failure completion")
            }
            receivedError = error as? RuuviDfuError
            completion.fulfill()
        }, receiveValue: { response in
            guard case let .log(log) = response else {
                return
            }
            loggedMessages.append(log.message)
            logExpectation.fulfill()
        })
        .store(in: &cancellables)

        sut.logWith(.application, message: "uploading")
        sut.dfuError(.deviceNotSupported, didOccurWithMessage: "legacy failed")

        wait(for: [logExpectation, completion], timeout: 1)
        XCTAssertEqual(loggedMessages, ["uploading"])
        XCTAssertEqual(receivedError?.description, "legacy failed")
    }

    func testFlasherIgnoresNonCompletedLegacyStates() {
        let sut = makeFlasher(legacyStarter: LegacyStarterSpy())
        let invertedCompletion = expectation(description: "no completion")
        invertedCompletion.isInverted = true

        sut.flashFirmware(
            uuid: "CB9FE4D2-19B4-4A78-8A4F-477D64FB1FE6",
            with: makeDummyFirmware()
        )
        .sink(receiveCompletion: { _ in
            invertedCompletion.fulfill()
        }, receiveValue: { _ in
        })
        .store(in: &cancellables)

        sut.dfuStateDidChange(to: .starting)

        wait(for: [invertedCompletion], timeout: 0.2)
    }

    func testFlasherStopAbortsLegacyController() {
        let controller = ServiceControllerSpy()
        let legacyStarter = LegacyStarterSpy(controller: controller)
        let sut = makeFlasher(legacyStarter: legacyStarter)
        _ = sut.flashFirmware(
            uuid: "CB9FE4D2-19B4-4A78-8A4F-477D64FB1FE6",
            with: makeDummyFirmware()
        )

        let stopped = sut.stopFlashFirmware(device: makeDevice())

        XCTAssertTrue(stopped)
        XCTAssertEqual(controller.abortCalls, 1)
    }

    func testFlasherStopReturnsFalseWithoutActiveOperations() {
        let stopped = makeFlasher().stopFlashFirmware(device: makeDevice())
        XCTAssertFalse(stopped)
    }

    func testFlasherFailsWhenNoFirmwareFilesProvided() {
        let sut = makeFlasher()
        let expectation = expectation(description: "empty files failure")
        var receivedError: RuuviDfuError?

        sut.flashFirmware(dfuDevice: makeDevice(), with: [])
            .sink(receiveCompletion: { completion in
                guard case let .failure(error) = completion else {
                    return XCTFail("Expected failure completion")
                }
                receivedError = error as? RuuviDfuError
                expectation.fulfill()
            }, receiveValue: { _ in
                XCTFail("Unexpected upload value")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedError?.description, "No firmware files provided")
    }

    func testFlasherFailsWhenFirmwareFileIsMissing() {
        let sut = makeFlasher(fileExists: { _ in false })
        let expectation = expectation(description: "missing file failure")
        var receivedError: RuuviDfuError?
        let url = URL(fileURLWithPath: "/tmp/ruuvi.bin")

        sut.flashFirmware(dfuDevice: makeDevice(), with: [url])
            .sink(receiveCompletion: { completion in
                guard case let .failure(error) = completion else {
                    return XCTFail("Expected failure completion")
                }
                receivedError = error as? RuuviDfuError
                expectation.fulfill()
            }, receiveValue: { _ in
                XCTFail("Unexpected upload value")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedError?.description, "File does not exist: ruuvi.bin")
    }

    func testFlasherPropagatesUploadSessionBuilderError() {
        let sut = makeFlasher(uploadSessionBuilder: ThrowingUploadSessionBuilderSpy(error: TestError()))
        let expectation = expectation(description: "builder error")
        var receivedError: TestError?

        sut.flashFirmware(dfuDevice: makeDevice(), with: [URL(fileURLWithPath: "/tmp/firmware.bin")])
            .sink(receiveCompletion: { completion in
                guard case let .failure(error) = completion else {
                    return XCTFail("Expected failure completion")
                }
                receivedError = error as? TestError
                expectation.fulfill()
            }, receiveValue: { _ in
                XCTFail("Unexpected upload value")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1)
        XCTAssertNotNil(receivedError)
    }

    func testFlasherPropagatesLoadDataErrors() {
        let sut = makeFlasher(
            uploadSessionBuilder: UploadSessionBuilderSpy(
                session: UploadSessionSpy(resetManager: ResetManagerSpy(), fileManagers: [])
            ),
            fileExists: { _ in true },
            loadData: { _ in throw TestError() }
        )
        let expectation = expectation(description: "load data error")
        var receivedError: TestError?

        sut.flashFirmware(dfuDevice: makeDevice(), with: [URL(fileURLWithPath: "/tmp/firmware.bin")])
            .sink(receiveCompletion: { completion in
                guard case let .failure(error) = completion else {
                    return XCTFail("Expected failure completion")
                }
                receivedError = error as? TestError
                expectation.fulfill()
            }, receiveValue: { _ in
                XCTFail("Unexpected upload value")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1)
        XCTAssertNotNil(receivedError)
    }

    func testFlasherFailsWhenUploadCannotStart() {
        let resetManager = ResetManagerSpy()
        let fileManager = FileSystemManagerSpy(startResult: false)
        let builder = UploadSessionBuilderSpy(
            session: UploadSessionSpy(resetManager: resetManager, fileManagers: [fileManager])
        )
        let sut = makeFlasher(
            uploadSessionBuilder: builder,
            fileExists: { _ in true },
            loadData: { _ in Data([0x01, 0x02]) }
        )
        let expectation = expectation(description: "start failure")
        var receivedError: RuuviDfuError?
        let url = URL(fileURLWithPath: "/tmp/firmware.bin")

        sut.flashFirmware(dfuDevice: makeDevice(), with: [url])
            .sink(receiveCompletion: { completion in
                guard case let .failure(error) = completion else {
                    return XCTFail("Expected failure completion")
                }
                receivedError = error as? RuuviDfuError
                expectation.fulfill()
            }, receiveValue: { _ in
                XCTFail("Unexpected upload value")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedError?.description, "Failed to start upload for /lfs1/firmware.bin.")
        XCTAssertEqual(fileManager.uploadCalls.first?.name, "/lfs1/firmware.bin")
        XCTAssertEqual(resetManager.resetCalls, 0)
    }

    func testFlasherUsesCustomPartitionKeyForUploads() {
        UserDefaults.standard.set("/custom", forKey: "partition_key")
        let fileManager = FileSystemManagerSpy(startResult: false)
        let sut = makeFlasher(
            uploadSessionBuilder: UploadSessionBuilderSpy(
                session: UploadSessionSpy(resetManager: ResetManagerSpy(), fileManagers: [fileManager])
            ),
            fileExists: { _ in true },
            loadData: { _ in Data([0x01, 0x02]) }
        )
        let expectation = expectation(description: "custom partition upload failure")

        sut.flashFirmware(dfuDevice: makeDevice(), with: [URL(fileURLWithPath: "/tmp/firmware.bin")])
            .sink(receiveCompletion: { completion in
                guard case .failure = completion else {
                    return XCTFail("Expected failure completion")
                }
                expectation.fulfill()
            }, receiveValue: { _ in
                XCTFail("Unexpected upload value")
            })
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(fileManager.uploadCalls.first?.name, "/custom/firmware.bin")
    }

    func testFlasherUploadsMultipleFilesAggregatesProgressAndResetsDevice() {
        let resetManager = ResetManagerSpy()
        let firstManager = FileSystemManagerSpy(startResult: true)
        let secondManager = FileSystemManagerSpy(startResult: true)
        let builder = UploadSessionBuilderSpy(
            session: UploadSessionSpy(
                resetManager: resetManager,
                fileManagers: [firstManager, secondManager]
            )
        )
        let dataByName: [String: Data] = [
            "one.bin": Data([0x01, 0x02]),
            "two.bin": Data([0x03, 0x04, 0x05]),
        ]
        let sut = makeFlasher(
            uploadSessionBuilder: builder,
            fileExists: { _ in true },
            loadData: { url in
                dataByName[url.lastPathComponent] ?? Data()
            },
            scheduleNextUpload: { work in
                work()
            }
        )
        let completion = expectation(description: "uploads finished")
        let urls = [
            URL(fileURLWithPath: "/tmp/one.bin"),
            URL(fileURLWithPath: "/tmp/two.bin"),
        ]
        var progressValues: [Double] = []
        var didFinish = false

        sut.flashFirmware(dfuDevice: makeDevice(), with: urls)
            .sink(receiveCompletion: { result in
                guard case .finished = result else {
                    return XCTFail("Expected finished completion")
                }
                didFinish = true
                completion.fulfill()
            }, receiveValue: { response in
                switch response {
                case let .progress(value):
                    progressValues.append(value)
                case .done:
                    progressValues.append(1.0)
                case .log:
                    break
                }
            })
            .store(in: &cancellables)

        XCTAssertEqual(firstManager.uploadCalls.first?.name, "/lfs1/one.bin")
        sut.uploadProgressDidChange(bytesSent: 1, fileSize: 2, timestamp: Date())
        sut.uploadDidFinish()
        XCTAssertEqual(secondManager.uploadCalls.first?.name, "/lfs1/two.bin")
        sut.uploadProgressDidChange(bytesSent: 3, fileSize: 3, timestamp: Date())
        sut.uploadDidFinish()

        wait(for: [completion], timeout: 1)
        XCTAssertTrue(didFinish)
        XCTAssertEqual(progressValues.first ?? 0, 0.2, accuracy: 0.0001)
        XCTAssertEqual(progressValues.dropFirst().first ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(resetManager.resetCalls, 1)
    }

    func testFlasherCompletesZeroByteUploadWithoutFinalProgress() {
        let resetManager = ResetManagerSpy()
        let fileManager = FileSystemManagerSpy(startResult: true)
        let builder = UploadSessionBuilderSpy(
            session: UploadSessionSpy(resetManager: resetManager, fileManagers: [fileManager])
        )
        let sut = makeFlasher(
            uploadSessionBuilder: builder,
            fileExists: { _ in true },
            loadData: { _ in Data() }
        )
        let completion = expectation(description: "zero-byte upload finished")
        var progressValues: [Double] = []
        var doneCount = 0

        sut.flashFirmware(
            dfuDevice: makeDevice(),
            with: [URL(fileURLWithPath: "/tmp/empty.bin")]
        )
        .sink(receiveCompletion: { result in
            guard case .finished = result else {
                return XCTFail("Expected finished completion")
            }
            completion.fulfill()
        }, receiveValue: { response in
            switch response {
            case let .progress(value):
                progressValues.append(value)
            case .done:
                doneCount += 1
            case .log:
                break
            }
        })
        .store(in: &cancellables)

        sut.uploadDidFinish()

        wait(for: [completion], timeout: 1)
        XCTAssertEqual(fileManager.uploadCalls.first?.name, "/lfs1/empty.bin")
        XCTAssertTrue(progressValues.isEmpty)
        XCTAssertEqual(doneCount, 1)
        XCTAssertEqual(resetManager.resetCalls, 1)
    }

    func testFlasherStopCancelsActiveUploadAndPublishesFailure() {
        let resetManager = ResetManagerSpy()
        let fileManager = FileSystemManagerSpy(startResult: true)
        let builder = UploadSessionBuilderSpy(
            session: UploadSessionSpy(resetManager: resetManager, fileManagers: [fileManager])
        )
        let sut = makeFlasher(
            uploadSessionBuilder: builder,
            fileExists: { _ in true },
            loadData: { _ in Data([0x01]) }
        )
        let completion = expectation(description: "cancelled upload")
        var receivedError: RuuviDfuError?

        sut.flashFirmware(
            dfuDevice: makeDevice(),
            with: [URL(fileURLWithPath: "/tmp/cancel.bin")]
        )
        .sink(receiveCompletion: { result in
            guard case let .failure(error) = result else {
                return XCTFail("Expected failure completion")
            }
            receivedError = error as? RuuviDfuError
            completion.fulfill()
        }, receiveValue: { _ in
            XCTFail("Unexpected upload value")
        })
        .store(in: &cancellables)

        let stopped = sut.stopFlashFirmware(device: makeDevice())

        wait(for: [completion], timeout: 1)
        XCTAssertTrue(stopped)
        XCTAssertEqual(fileManager.cancelTransferCalls, 1)
        XCTAssertEqual(receivedError?.description, "Upload cancelled by user")
        XCTAssertEqual(resetManager.resetCalls, 0)
    }

    func testFlasherUploadFailurePublishesOriginalError() {
        let fileManager = FileSystemManagerSpy(startResult: true)
        let builder = UploadSessionBuilderSpy(
            session: UploadSessionSpy(
                resetManager: ResetManagerSpy(),
                fileManagers: [fileManager]
            )
        )
        let sut = makeFlasher(
            uploadSessionBuilder: builder,
            fileExists: { _ in true },
            loadData: { _ in Data([0x01]) }
        )
        let completion = expectation(description: "upload error propagated")
        var receivedError: TestError?

        sut.flashFirmware(
            dfuDevice: makeDevice(),
            with: [URL(fileURLWithPath: "/tmp/fail.bin")]
        )
        .sink(receiveCompletion: { result in
            guard case let .failure(error) = result else {
                return XCTFail("Expected failure completion")
            }
            receivedError = error as? TestError
            completion.fulfill()
        }, receiveValue: { _ in
            XCTFail("Unexpected upload value")
        })
        .store(in: &cancellables)

        sut.uploadDidFail(with: TestError())

        wait(for: [completion], timeout: 1)
        XCTAssertNotNil(receivedError)
    }

    func testFlasherUploadCancelPublishesCancellationError() {
        let fileManager = FileSystemManagerSpy(startResult: true)
        let builder = UploadSessionBuilderSpy(
            session: UploadSessionSpy(
                resetManager: ResetManagerSpy(),
                fileManagers: [fileManager]
            )
        )
        let sut = makeFlasher(
            uploadSessionBuilder: builder,
            fileExists: { _ in true },
            loadData: { _ in Data([0x01]) }
        )
        let completion = expectation(description: "upload cancel propagated")
        var receivedError: RuuviDfuError?

        sut.flashFirmware(
            dfuDevice: makeDevice(),
            with: [URL(fileURLWithPath: "/tmp/cancelled.bin")]
        )
        .sink(receiveCompletion: { result in
            guard case let .failure(error) = result else {
                return XCTFail("Expected failure completion")
            }
            receivedError = error as? RuuviDfuError
            completion.fulfill()
        }, receiveValue: { _ in
            XCTFail("Unexpected upload value")
        })
        .store(in: &cancellables)

        sut.uploadDidCancel()

        wait(for: [completion], timeout: 1)
        XCTAssertEqual(receivedError?.description, "Upload cancelled")
    }

    func testNordicLegacyStarterForwardsDelegatesAndWrapsController() {
        let initiator = NordicInitiatorSpy()
        let controller = NordicControllerSpy()
        initiator.controllerToReturn = controller
        let sut = NordicDfuLegacyStarter(initiator: initiator)
        let delegate = makeFlasher()
        let progressDelegate = makeFlasher()
        let logger = makeFlasher()

        sut.delegate = delegate
        sut.progressDelegate = progressDelegate
        sut.logger = logger

        XCTAssertTrue((sut.delegate as AnyObject?) === delegate)
        XCTAssertTrue((sut.progressDelegate as AnyObject?) === progressDelegate)
        XCTAssertTrue((sut.logger as AnyObject?) === logger)

        let wrappedController = sut.start(
            firmware: makeDummyFirmware(),
            targetIdentifier: UUID(uuidString: "CB9FE4D2-19B4-4A78-8A4F-477D64FB1FE6")!
        )

        XCTAssertTrue(initiator.delegate === delegate)
        XCTAssertTrue(initiator.progressDelegate === progressDelegate)
        XCTAssertTrue(initiator.logger === logger)
        XCTAssertEqual(initiator.startedUUIDs.count, 1)
        XCTAssertTrue(wrappedController?.abort() == true)
        XCTAssertEqual(controller.abortCalls, 1)
    }

    func testNordicDfuServiceInitiatorProtocolExtensionsUseRealInitiator() {
        let queue = DispatchQueue(label: "RuuviDFUTests.RealNordicInitiator")
        let initiator = DFUServiceInitiator(
            queue: queue,
            delegateQueue: queue,
            progressQueue: queue,
            loggerQueue: queue
        )

        let starter = initiator.makeStarter(firmware: makeDummyFirmware())
        let controller = starter.start(targetWithIdentifier: UUID())

        _ = controller?.abort()
        XCTAssertNotNil(starter)
    }

    func testDefaultManagerAdapterExecutesInjectedResetClosure() {
        let completion = expectation(description: "reset completion")
        var resetCalls = 0
        let sut = DefaultManagerAdapter { done in
            resetCalls += 1
            done()
        }

        sut.reset {
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1)
        XCTAssertEqual(resetCalls, 1)
    }

    func testFileSystemManagerAdapterForwardsUploadAndCancelClosures() {
        let delegate = UploadDelegateSpy()
        var uploadRequests: [(name: String, data: Data)] = []
        var cancelCalls = 0
        let sut = FileSystemManagerAdapter(
            uploadClosure: { name, data, _ in
                uploadRequests.append((name, data))
                return true
            },
            cancelClosure: {
                cancelCalls += 1
            }
        )

        XCTAssertTrue(sut.upload(name: "/lfs1/test.bin", data: Data([0x01]), delegate: delegate))
        sut.cancelTransfer()

        XCTAssertEqual(uploadRequests.first?.name, "/lfs1/test.bin")
        XCTAssertEqual(uploadRequests.first?.data, Data([0x01]))
        XCTAssertEqual(cancelCalls, 1)
    }

    func testMcuManagerUploadSessionUsesInjectedFactories() {
        let transport = McuTransportSpy(callbackMode: .none)
        let resetManager = ResetManagerSpy()
        let fileManager = FileSystemManagerSpy(startResult: true)
        var resetFactoryCalls = 0
        var fileFactoryCalls = 0
        let sut = McuManagerDfuUploadSession(
            peripheral: makeDevice().peripheral,
            transportFactory: { _ in transport },
            resetManagerFactory: { receivedTransport in
                XCTAssertTrue(receivedTransport === transport)
                resetFactoryCalls += 1
                return resetManager
            },
            fileSystemManagerFactory: { receivedTransport in
                XCTAssertTrue(receivedTransport === transport)
                fileFactoryCalls += 1
                return fileManager
            }
        )

        let producedFileManager = sut.makeFileSystemManager()

        XCTAssertTrue(sut.resetManager as AnyObject === resetManager)
        XCTAssertTrue(producedFileManager as AnyObject === fileManager)
        XCTAssertEqual(resetFactoryCalls, 1)
        XCTAssertEqual(fileFactoryCalls, 1)
    }

    func testDefaultUploadSessionBuilderUsesInjectedFactory() throws {
        let session = UploadSessionSpy(resetManager: ResetManagerSpy(), fileManagers: [])
        let sut = DefaultDfuUploadSessionBuilder { _ in
            session
        }

        let builtSession = try sut.makeSession(for: makeDevice().peripheral)

        XCTAssertTrue(builtSession as AnyObject === session)
    }

    func testDefaultUploadSessionBuilderCreatesSessionWithDefaultAdaptersForInjectedTransport()
        throws {
        let sut = DefaultDfuUploadSessionBuilder(
            transportFactory: { _ in McuTransportSpy(callbackMode: .none) }
        )

        let session = try sut.makeSession(for: makeDevice().peripheral)

        XCTAssertTrue(session is McuManagerDfuUploadSession)
        XCTAssertTrue(session.resetManager is DefaultManagerAdapter)
        XCTAssertTrue(session.makeFileSystemManager() is FileSystemManagerAdapter)
    }

    func testDefaultUploadSessionBuilderCreatesDefaultMcuSession() throws {
        let sut = DefaultDfuUploadSessionBuilder()

        let session = try sut.makeSession(for: makeDevice().peripheral)

        XCTAssertTrue(session is McuManagerDfuUploadSession)
        XCTAssertTrue(session.resetManager is DefaultManagerAdapter)
        XCTAssertTrue(session.makeFileSystemManager() is FileSystemManagerAdapter)
    }

    func testDefaultManagerAdapterWithRealManagerInvokesCompletionThroughTransport() {
        let transport = McuTransportSpy(callbackMode: .success)
        let sut = DefaultManagerAdapter(manager: DefaultManager(transport: transport))
        let completion = expectation(description: "reset completion")

        sut.reset {
            completion.fulfill()
        }

        wait(for: [completion], timeout: 1)
        XCTAssertEqual(transport.sentPackets.count, 1)
    }

    func testFileSystemManagerAdapterWithRealManagerStartsTransferAndAllowsRestartAfterCancel() {
        let transport = McuTransportSpy(callbackMode: .none)
        let sut = FileSystemManagerAdapter(manager: FileSystemManager(transport: transport))
        let delegate = UploadDelegateSpy()

        XCTAssertTrue(sut.upload(name: "/lfs1/test.bin", data: Data([0x01]), delegate: delegate))
        XCTAssertFalse(sut.upload(name: "/lfs1/test.bin", data: Data([0x02]), delegate: delegate))
        XCTAssertEqual(transport.sentPackets.count, 1)

        sut.cancelTransfer()

        XCTAssertTrue(sut.upload(name: "/lfs1/test.bin", data: Data([0x03]), delegate: delegate))
        XCTAssertEqual(transport.sentPackets.count, 2)
    }

    func testFlasherDefaultScheduleStartsNextUploadAfterDelay() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let firstURL = tempDirectory.appendingPathComponent("one.bin")
        let secondURL = tempDirectory.appendingPathComponent("two.bin")
        try Data([0x01]).write(to: firstURL)
        try Data([0x02]).write(to: secondURL)

        let firstManager = FileSystemManagerSpy(startResult: true)
        let secondManager = FileSystemManagerSpy(startResult: true)
        let sut = DfuFlasher(
            queue: DispatchQueue(label: "RuuviDFUTests.DefaultSchedule"),
            legacyStarter: LegacyStarterSpy(),
            uploadSessionBuilder: UploadSessionBuilderSpy(
                session: UploadSessionSpy(
                    resetManager: ResetManagerSpy(),
                    fileManagers: [firstManager, secondManager]
                )
            )
        )

        _ = sut.flashFirmware(dfuDevice: makeDevice(), with: [firstURL, secondURL])
        XCTAssertEqual(firstManager.uploadCalls.first?.name, "/lfs1/one.bin")

        sut.uploadDidFinish()

        let nextUploadStarted = expectation(description: "next upload started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            if secondManager.uploadCalls.first?.name == "/lfs1/two.bin" {
                nextUploadStarted.fulfill()
            }
        }

        wait(for: [nextUploadStarted], timeout: 1)
    }

    func testFlasherHandlesUploadSessionClearedBeforeUploadStarts() {
        let session = UploadSessionSpy(
            resetManager: ResetManagerSpy(),
            fileManagers: [FileSystemManagerSpy(startResult: true)]
        )
        var sut: DfuFlasher!
        sut = makeFlasher(
            uploadSessionBuilder: UploadSessionBuilderSpy(session: session),
            fileExists: { _ in true },
            loadData: { _ in
                sut.uploadDidCancel()
                return Data([0x01])
            }
        )

        _ = sut.flashFirmware(
            dfuDevice: makeDevice(),
            with: [URL(fileURLWithPath: "/tmp/reentrant.bin")]
        )

        XCTAssertEqual(session.makeFileSystemManagerCalls, 0)
    }

    func testFlasherScheduledContinuationAfterCleanupFinishesWithoutReset() {
        let resetManager = ResetManagerSpy()
        let fileManager = FileSystemManagerSpy(startResult: true)
        var scheduledContinuation: (() -> Void)?
        let sut = makeFlasher(
            uploadSessionBuilder: UploadSessionBuilderSpy(
                session: UploadSessionSpy(
                    resetManager: resetManager,
                    fileManagers: [fileManager]
                )
            ),
            fileExists: { _ in true },
            loadData: { _ in Data([0x01]) },
            scheduleNextUpload: { work in
                scheduledContinuation = work
            }
        )
        let completion = expectation(description: "cancelled before continuation")
        var receivedError: RuuviDfuError?

        sut.flashFirmware(
            dfuDevice: makeDevice(),
            with: [URL(fileURLWithPath: "/tmp/cancel-before-continuation.bin")]
        )
        .sink(receiveCompletion: { result in
            guard case let .failure(error) = result else {
                return XCTFail("Expected failure completion")
            }
            receivedError = error as? RuuviDfuError
            completion.fulfill()
        }, receiveValue: { _ in
            XCTFail("Unexpected upload value")
        })
        .store(in: &cancellables)

        sut.uploadDidFinish()
        XCTAssertNotNil(scheduledContinuation)
        XCTAssertTrue(sut.stopFlashFirmware(device: makeDevice()))

        scheduledContinuation?()

        wait(for: [completion], timeout: 1)
        XCTAssertEqual(receivedError?.description, "Upload cancelled by user")
        XCTAssertEqual(fileManager.cancelTransferCalls, 1)
        XCTAssertEqual(resetManager.resetCalls, 0)
    }

    func testFlasherOmittedDefaultClosuresReadExistingFilesBeforeUploadStarts() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let firmwareURL = tempDirectory.appendingPathComponent("one.bin")
        try Data([0x01, 0x02]).write(to: firmwareURL)

        let fileManager = FileSystemManagerSpy(startResult: false)
        let sut = DfuFlasher(
            queue: DispatchQueue(label: "RuuviDFUTests.DefaultClosures"),
            legacyStarter: LegacyStarterSpy(),
            uploadSessionBuilder: UploadSessionBuilderSpy(
                session: UploadSessionSpy(
                    resetManager: ResetManagerSpy(),
                    fileManagers: [fileManager]
                )
            )
        )

        _ = sut.flashFirmware(dfuDevice: makeDevice(), with: [firmwareURL])

        XCTAssertEqual(fileManager.uploadCalls.first?.name, "/lfs1/one.bin")
        XCTAssertEqual(fileManager.uploadCalls.first?.data, Data([0x01, 0x02]))
    }
}

private func makeFlasher(
    legacyStarter: DfuLegacyServiceStarting = LegacyStarterSpy(),
    uploadSessionBuilder: DfuUploadSessionBuilding = UploadSessionBuilderSpy(
        session: UploadSessionSpy(resetManager: ResetManagerSpy(), fileManagers: [])
    ),
    fileExists: @escaping (String) -> Bool = { _ in true },
    loadData: @escaping (URL) throws -> Data = { _ in Data([0x01]) },
    scheduleNextUpload: @escaping (@escaping () -> Void) -> Void = { work in work() }
) -> DfuFlasher {
    DfuFlasher(
        queue: DispatchQueue(label: "RuuviDFUTests"),
        legacyStarter: legacyStarter,
        uploadSessionBuilder: uploadSessionBuilder,
        fileExists: fileExists,
        loadData: loadData,
        scheduleNextUpload: scheduleNextUpload
    )
}

private func makeDummyFirmware() -> DFUFirmware {
    DFUFirmware(binFile: Data([0x01, 0x02, 0x03]), datFile: nil, type: .application)
}

private func makeDevice(uuid: String = UUID().uuidString) -> DFUDevice {
    DFUDevice(
        uuid: uuid,
        rssi: -60,
        isConnectable: true,
        name: "Ruuvi",
        peripheral: unsafeBitCast(FakePeripheral(), to: CBPeripheral.self)
    )
}

private final class DummyObserver: NSObject {}
private final class FakePeripheral: NSObject {
    @objc let identifier = UUID()
    @objc let name = "FakePeripheral"

    @objc func maximumWriteValueLength(for type: CBCharacteristicWriteType) -> Int {
        23
    }

    @objc(maximumWriteValueLengthForType:)
    func maximumWriteValueLengthForType(_ type: CBCharacteristicWriteType) -> Int {
        23
    }
}

private final class ScannerSpy: DfuScanner {
    var includeScanServicesValues: [Bool] = []
    var scanCallCount = 0
    var lostCallCount = 0
    var tokenToReturn = RuuviDFUToken {}

    override func setIncludeScanServices(_ includeScanServices: Bool) {
        includeScanServicesValues.append(includeScanServices)
    }

    override func scan<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, DFUDevice) -> Void
    ) -> RuuviDFUToken {
        scanCallCount += 1
        return tokenToReturn
    }

    override func lost<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, DFUDevice) -> Void
    ) -> RuuviDFUToken {
        lostCallCount += 1
        return tokenToReturn
    }
}

private final class DfuProtocolSpy: RuuviDFU {
    var singleFileRequests: [(device: DFUDevice, url: URL)] = []

    func scan<T: AnyObject>(
        _ observer: T,
        includeScanServices: Bool,
        closure: @escaping (T, DFUDevice) -> Void
    ) -> RuuviDFUToken {
        RuuviDFUToken {}
    }

    func lost<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, DFUDevice) -> Void
    ) -> RuuviDFUToken {
        RuuviDFUToken {}
    }

    func firmwareFromUrl(url: URL) -> DFUFirmware? {
        nil
    }

    func flashFirmware(
        uuid: String,
        with firmware: DFUFirmware
    ) -> AnyPublisher<FlashResponse, Error> {
        Empty().eraseToAnyPublisher()
    }

    func flashFirmware(
        dfuDevice: DFUDevice,
        with firmwareURL: URL
    ) -> AnyPublisher<FlashResponse, Error> {
        singleFileRequests.append((dfuDevice, firmwareURL))
        return Empty().eraseToAnyPublisher()
    }

    func stopFlashFirmware(device: DFUDevice) -> Bool {
        false
    }
}

private final class FlasherSpy: DfuFlasher {
    var legacyFlashCalls: [(uuid: String, firmware: DFUFirmware)] = []
    var fileFlashCalls: [(device: DFUDevice, urls: [URL])] = []
    var stopCalls: [DFUDevice] = []
    var stopResult = false

    init() {
        super.init(
            queue: DispatchQueue(label: "FlasherSpy"),
            legacyStarter: LegacyStarterSpy(),
            uploadSessionBuilder: UploadSessionBuilderSpy(
                session: UploadSessionSpy(resetManager: ResetManagerSpy(), fileManagers: [])
            )
        )
    }

    override func flashFirmware(
        uuid: String,
        with firmware: DFUFirmware
    ) -> AnyPublisher<FlashResponse, Error> {
        legacyFlashCalls.append((uuid, firmware))
        return Empty().eraseToAnyPublisher()
    }

    override func flashFirmware(
        dfuDevice: DFUDevice,
        with firmwareURLs: [URL]
    ) -> AnyPublisher<FlashResponse, Error> {
        fileFlashCalls.append((dfuDevice, firmwareURLs))
        return Empty().eraseToAnyPublisher()
    }

    override func stopFlashFirmware(device: DFUDevice) -> Bool {
        stopCalls.append(device)
        return stopResult
    }
}

private final class ServiceControllerSpy: DfuServiceControlling {
    var abortCalls = 0
    var abortResult = true

    func abort() -> Bool {
        abortCalls += 1
        return abortResult
    }
}

private final class NordicControllerSpy: NordicDfuServiceControlling {
    var abortCalls = 0

    func abort() -> Bool {
        abortCalls += 1
        return true
    }
}

private final class NordicInitiatorSpy: NordicDfuServiceInitiating, NordicDfuTargetStarting {
    var delegate: DFUServiceDelegate?
    var progressDelegate: DFUProgressDelegate?
    var logger: LoggerDelegate?
    var controllerToReturn: NordicDfuServiceControlling?
    var startedUUIDs: [UUID] = []
    var startedFirmware: [DFUFirmware] = []

    func makeStarter(firmware: DFUFirmware) -> NordicDfuTargetStarting {
        startedFirmware.append(firmware)
        return self
    }

    func start(targetWithIdentifier: UUID) -> NordicDfuServiceControlling? {
        startedUUIDs.append(targetWithIdentifier)
        return controllerToReturn
    }
}

private final class LegacyStarterSpy: DfuLegacyServiceStarting {
    var delegate: DFUServiceDelegate?
    var progressDelegate: DFUProgressDelegate?
    var logger: LoggerDelegate?
    var startedUUIDs: [UUID] = []
    private let controller: DfuServiceControlling?

    init(controller: DfuServiceControlling? = nil) {
        self.controller = controller
    }

    func start(firmware: DFUFirmware, targetIdentifier: UUID) -> DfuServiceControlling? {
        startedUUIDs.append(targetIdentifier)
        return controller
    }
}

private final class FileSystemManagerSpy: DfuFileSystemManaging {
    struct UploadCall {
        let name: String
        let data: Data
    }

    let startResult: Bool
    var uploadCalls: [UploadCall] = []
    var cancelTransferCalls = 0

    init(startResult: Bool) {
        self.startResult = startResult
    }

    @discardableResult
    func upload(name: String, data: Data, delegate: FileUploadDelegate) -> Bool {
        uploadCalls.append(UploadCall(name: name, data: data))
        return startResult
    }

    func cancelTransfer() {
        cancelTransferCalls += 1
    }
}

private final class ResetManagerSpy: DfuResetManaging {
    var resetCalls = 0

    func reset(completion: @escaping () -> Void) {
        resetCalls += 1
        completion()
    }
}

private final class UploadSessionSpy: DfuUploadSession {
    let resetManager: DfuResetManaging
    private var fileManagers: [DfuFileSystemManaging]
    private(set) var makeFileSystemManagerCalls = 0

    init(resetManager: DfuResetManaging, fileManagers: [DfuFileSystemManaging]) {
        self.resetManager = resetManager
        self.fileManagers = fileManagers
    }

    func makeFileSystemManager() -> DfuFileSystemManaging {
        makeFileSystemManagerCalls += 1
        if !fileManagers.isEmpty {
            return fileManagers.removeFirst()
        }
        return FileSystemManagerSpy(startResult: false)
    }
}

private struct UploadSessionBuilderSpy: DfuUploadSessionBuilding {
    let session: DfuUploadSession

    func makeSession(for peripheral: CBPeripheral) throws -> DfuUploadSession {
        session
    }
}

private struct ThrowingUploadSessionBuilderSpy: DfuUploadSessionBuilding {
    let error: Error

    func makeSession(for peripheral: CBPeripheral) throws -> DfuUploadSession {
        throw error
    }
}

private final class UploadDelegateSpy: NSObject, FileUploadDelegate {
    func uploadProgressDidChange(bytesSent: Int, fileSize: Int, timestamp: Date) {}
    func uploadDidFail(with error: any Error) {}
    func uploadDidCancel() {}
    func uploadDidFinish() {}
}

private final class McuTransportSpy: NSObject, McuMgrTransport, DfuTransporting {
    enum CallbackMode {
        case none
        case success
    }

    var mtu: Int! = 128
    var sentPackets: [(data: Data, timeout: Int)] = []
    var connectCalls = 0
    var closeCalls = 0
    private let callbackMode: CallbackMode
    private var observers: [ConnectionObserver] = []

    init(callbackMode: CallbackMode) {
        self.callbackMode = callbackMode
    }

    func getScheme() -> McuMgrScheme {
        .ble
    }

    func send<T: McuMgrResponse>(data: Data, timeout: Int, callback: @escaping McuMgrCallback<T>) {
        sentPackets.append((data, timeout))
        if callbackMode == .success {
            callback(nil, nil)
        }
    }

    func connect(_ callback: @escaping ConnectionCallback) {
        connectCalls += 1
        callback(.connected)
    }

    func close() {
        closeCalls += 1
    }

    func addObserver(_ observer: ConnectionObserver) {
        observers.append(observer)
    }

    func removeObserver(_ observer: ConnectionObserver) {
        observers.removeAll { $0 === observer }
    }
}

private struct TestError: Error {}
