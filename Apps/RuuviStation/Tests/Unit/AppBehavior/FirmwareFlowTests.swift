import BTKit
import Combine
import Foundation
import RuuviDaemon
import RuuviDFU
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviPresenters
import RuuviStorage
import SwiftUI
import UIKit
import Vision
import XCTest
@testable import station

@MainActor final class FirmwareFlowTests: XCTestCase {
    func testAirAndTagScreensRenderDownloadDiscoveryFlashingAndVerifiedSuccess() async throws {
        for version in [225, 5] {
            let fixture = try FirmwareFlowFixture(version: version)
            defer { fixture.close() }
            try await fixture.show()
            try await fixture.offerUpgrade()
            var images = Set<Data>()
            images.insert(try await fixture.image(named: "Firmware offer \(version)", test: self))
            fixture.model.send(event: .onStartUpgrade(fixture.latest, fixture.current))
            try await waitForFirmwareState { fixture.interactor.downloads == 1 }
            let progress = Progress(totalUnitCount: 100)
            progress.completedUnitCount = 25
            fixture.interactor.download.send(.progress(progress))
            try await waitForFirmwareState { fixture.model.downloadProgress == 0.25 }
            images.insert(try await fixture.image(named: "Firmware downloading \(version)", test: self))
            fixture.interactor.download.send(
                .response(
                    appUrl: fixture.app, fullUrl: fixture.full, additionalFiles: fixture.files))
            try await waitForFirmwareState { !fixture.interactor.listeners.isEmpty }
            images.insert(try await fixture.image(named: "Firmware instructions \(version)", test: self))
            fixture.interactor.listeners[0](.success(fixture.device))
            try await waitForFirmwareState { !fixture.interactor.lost.isEmpty }
            images.insert(try await fixture.image(named: "Firmware ready \(version)", test: self))
            fixture.confirm()
            try await waitForFirmwareState { fixture.interactor.flashes == 1 }
            XCTAssertEqual(fixture.interactor.lastFiles, [fixture.app, fixture.full] + fixture.files)
            fixture.interactor.flash.send(.progress(0.5))
            fixture.interactor.flash.send(.log(.init(message: "Writing firmware", time: Date())))
            try await waitForFirmwareState { fixture.model.flashProgress == 0.5 }
            images.insert(try await fixture.image(named: "Firmware flashing \(version)", test: self))
            fixture.interactor.flash.send(.done)
            if version == 225 {
                try await waitForFirmwareState { fixture.interactor.waits == 1 }
                images.insert(try await fixture.image(named: "Firmware reboot waiting", test: self))
                fixture.interactor.air.send(())
                try await waitForFirmwareState { fixture.interactor.serves.count == 2 }
                fixture.interactor.serves[1](.success(.init(version: fixture.latest.version)))
            } else {
                try await waitForFirmwareState { fixture.interactor.serves.count == 2 }
                fixture.interactor.serves[1](.success(.init(version: fixture.latest.version)))
                try await waitForFirmwareState { fixture.interactor.serves.count == 3 }
                fixture.interactor.serves[2](.success(.init(version: fixture.latest.version)))
            }
            try await waitForFirmwareState {
                if case .firmwareAfterUpdate = fixture.model.state { return true }
                return false
            }
            images.insert(try await fixture.image(named: "Firmware success \(version)", test: self))
            XCTAssertGreaterThanOrEqual(images.count, 5)
            XCTAssertEqual(fixture.model.isRuuviAir(), version == 225)
            fixture.close()
            try await waitForFirmwareState { fixture.daemon.starts == 1 }
        }
    }

    func testAirVersionReadRetriesStartNewRequestsAfterReboot() async throws {
        let fixture = try FirmwareFlowFixture(version: 225)
        defer { fixture.close() }
        try await fixture.show()
        try await fixture.reachReboot()
        fixture.interactor.air.send(())
        try await waitForFirmwareState { fixture.interactor.serves.count == 2 }
        fixture.interactor.serves[1](.failure(URLError(.networkConnectionLost)))
        try await waitForFirmwareState { fixture.interactor.serves.count == 3 }
        guard fixture.interactor.serves.count == 3 else { return }
        fixture.interactor.serves[2](.success(.init(version: fixture.latest.version)))
        try await waitForFirmwareState {
            if case .firmwareAfterUpdate = fixture.model.state { return true }
            return false
        }
    }

    func testClosingDuringAirRebootReleasesTheModelAndCancelsItsSubscription() async throws {
        var fixture: FirmwareFlowFixture? = try FirmwareFlowFixture(version: 225)
        weak var model = fixture?.model
        let interactor = try XCTUnwrap(fixture?.interactor)
        try await fixture?.show()
        try await fixture?.reachReboot()
        fixture?.close()
        fixture = nil
        try await waitForFirmwareState { model == nil }
        interactor.air.send(())
        XCTAssertEqual(interactor.serves.count, 1, "A closed firmware screen must not read or update the device")
    }

    func testAirRebootFailureAndVersionMismatchRenderAnErrorInsteadOfSuccess() async throws {
        for mismatch in [false, true] {
            let fixture = try FirmwareFlowFixture(version: 225)
            defer { fixture.close() }
            try await fixture.show()
            try await fixture.reachReboot()
            if mismatch {
                fixture.interactor.air.send(())
                try await waitForFirmwareState { fixture.interactor.serves.count == 2 }
                fixture.interactor.serves[1](.success(.init(version: "0.0.1")))
            } else {
                fixture.interactor.air.send(completion: .failure(DFUError.airDeviceTimeout))
            }
            try await waitForFirmwareState {
                if case .error = fixture.model.state { return true }
                return false
            }
            guard case .error(let error) = fixture.model.state else { return XCTFail("Expected failure") }
            if mismatch {
                XCTAssertEqual(
                    error as? DFUError, .airVersionMismatch(expected: fixture.latest.version, actual: "0.0.1"))
            } else {
                XCTAssertEqual(error as? DFUError, .airDeviceTimeout)
            }
            _ = try await fixture.image(
                named: mismatch ? "Firmware version mismatch" : "Firmware reboot timeout", test: self)
        }
    }

    func testUnavailableCurrentVersionOffersUpdateAndDownloadFailureIsVisible() async throws {
        let fixture = try FirmwareFlowFixture(version: 5)
        defer { fixture.close() }
        try await fixture.show()
        fixture.interactor.release.send(fixture.latest)
        try await waitForFirmwareState { fixture.interactor.serves.count == 1 }
        fixture.interactor.serves[0](.failure(URLError(.timedOut)))
        try await waitForFirmwareState {
            if case .isAbleToUpgrade(_, nil) = fixture.model.state { return true }
            return false
        }
        _ = try await fixture.image(named: "Firmware unknown current version", test: self)
        fixture.model.send(event: .onStartUpgrade(fixture.latest, nil))
        try await waitForFirmwareState { fixture.interactor.downloads == 1 }
        fixture.interactor.download.send(completion: .failure(URLError(.notConnectedToInternet)))
        try await waitForFirmwareState {
            if case .error = fixture.model.state { return true }
            return false
        }
        _ = try await fixture.image(named: "Firmware download error", test: self)
    }

    func testAlreadyCurrentAndReleaseLoadFailureRenderDistinctOutcomes() async throws {
        for failing in [false, true] {
            let fixture = try FirmwareFlowFixture(version: 5)
            defer { fixture.close() }
            try await fixture.show()
            if failing {
                fixture.interactor.release.send(completion: .failure(URLError(.badServerResponse)))
                try await waitForFirmwareState {
                    if case .error = fixture.model.state { return true }
                    return false
                }
            } else {
                fixture.interactor.release.send(fixture.latest)
                try await waitForFirmwareState { fixture.interactor.serves.count == 1 }
                fixture.interactor.serves[0](.success(.init(version: fixture.latest.version)))
                try await waitForFirmwareState {
                    if case .noNeedToUpgrade = fixture.model.state { return true }
                    return false
                }
            }
            XCTAssertEqual(fixture.interactor.downloads, 0)
            _ = try await fixture.image(
                named: failing ? "Firmware release error" : "Firmware already current", test: self)
        }
    }
}

@MainActor private final class FirmwareFlowFixture {
    let interactor = FirmwareFlowInteractor()
    let daemon = FirmwareFlowDaemon()
    let model: DFUViewModel
    let latest = LatestRelease(version: "3.10.0", assets: [])
    let current = CurrentRelease(version: "3.9.0")
    let app = URL(fileURLWithPath: "/firmware/app.bin")
    let full = URL(fileURLWithPath: "/firmware/full.bin")
    let files = [URL(fileURLWithPath: "/firmware/filesystem.bin")]
    let device: DFUDevice
    private var window: UIWindow?
    private var host: UIHostingController<DFUUIView>?
    private let originalIdleTimer = UIApplication.shared.isIdleTimerDisabled
    init(version: Int) throws {
        let resolver = AppAssembly.shared.assembler.resolver
        let sensor = RuuviTagSensorStruct(
            version: version, firmwareVersion: nil, luid: nil, macId: UUID().uuidString.mac,
            serviceUUID: nil, isConnectable: true, name: "Firmware flow", isClaimed: false, isOwner: true,
            owner: nil, ownersPlan: nil, isCloudSensor: false, canShare: false, sharedTo: [], maxHistoryDays: nil)
        let peripheral = FirmwareFlowPeripheral()
        device = .init(
            uuid: peripheral.identifier.uuidString, rssi: -50, isConnectable: true,
            name: "RuuviBoot", peripheral: peripheral)
        model = DFUViewModel(
            interactor: interactor, foreground: BTKit.foreground,
            idPersistence: try XCTUnwrap(resolver.resolve(RuuviLocalIDs.self)),
            sqiltePersistence: try XCTUnwrap(resolver.resolve(RuuviPersistence.self, name: "sqlite")),
            ruuviTag: sensor, ruuviPool: try XCTUnwrap(resolver.resolve(RuuviPool.self)),
            ruuviStorage: try XCTUnwrap(resolver.resolve(RuuviStorage.self)), settings: AppTestSettings(),
            propertiesDaemon: daemon, activityPresenter: FirmwareFlowActivity())
    }
    func show() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let host = UIHostingController(rootView: DFUUIView(viewModel: model))
        host.overrideUserInterfaceStyle = .light
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        window.rootViewController = host
        window.isHidden = false
        self.window = window
        self.host = host
        try await waitForFirmwareState { self.interactor.loads == 1 }
    }
    func offerUpgrade() async throws {
        interactor.release.send(latest)
        try await waitForFirmwareState { self.interactor.serves.count == 1 }
        interactor.serves[0](.success(current))
        try await waitForFirmwareState {
            if case .isAbleToUpgrade = self.model.state { return true }
            return false
        }
    }
    func reachReboot() async throws {
        try await offerUpgrade()
        model.send(event: .onStartUpgrade(latest, current))
        try await waitForFirmwareState { self.interactor.downloads == 1 }
        interactor.download.send(.response(appUrl: app, fullUrl: full, additionalFiles: files))
        try await waitForFirmwareState { !self.interactor.listeners.isEmpty }
        interactor.listeners[0](.success(device))
        try await waitForFirmwareState { !self.interactor.lost.isEmpty }
        confirm()
        try await waitForFirmwareState { self.interactor.flashes == 1 }
        interactor.flash.send(.done)
        try await waitForFirmwareState { self.interactor.waits == 1 }
    }
    func confirm() {
        model.send(
            event: .onUserDidConfirmToFlash(
                latest, current, dfuDevice: device, appUrl: app, fullUrl: full, additionalFiles: files))
    }
    func image(named name: String, test: XCTestCase) async throws -> Data {
        try await Task.sleep(nanoseconds: 30_000_000)
        let host = try XCTUnwrap(host)
        host.view.layoutIfNeeded()
        if name.hasPrefix("Firmware instructions") || name.hasPrefix("Firmware ready") {
            let instructions = try XCTUnwrap(
                host.view.allDescendants.compactMap { $0 as? UILabel }.first {
                    ($0.attributedText?.length ?? 0) > 100
                })
            let frame = instructions.convert(instructions.bounds, to: host.view)
            XCTAssertGreaterThanOrEqual(frame.minX, 0, "Firmware instructions must not clip off the left edge")
            XCTAssertLessThanOrEqual(frame.maxX, host.view.bounds.maxX, "Instructions must wrap within the screen")
            XCTAssertGreaterThan(frame.height, 100, "Multi-step instructions must wrap onto readable lines")
        }
        let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { host.view.layer.render(in: $0.cgContext) }
        let data = try XCTUnwrap(image.pngData())
        XCTAssertGreaterThan(data.count, 5000)
        if name.hasPrefix("Firmware success") {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
            let observations = request.results ?? []
            let title = try XCTUnwrap(
                observations.first {
                    $0.topCandidates(1).first?.string.localizedCaseInsensitiveContains(
                        RuuviLocalization.DFUUIView.navigationTitle) == true
                })
            let message =
                model.isRuuviAir() ? RuuviLocalization.updateSuccessfulAir : RuuviLocalization.updateSuccessfulTag
            let prefix = message.split(separator: " ").prefix(3).joined(separator: " ")
            let body = try XCTUnwrap(
                observations.first {
                    $0.topCandidates(1).first?.string.localizedCaseInsensitiveContains(prefix) == true
                })
            XCTAssertLessThan(
                body.boundingBox.maxY, title.boundingBox.minY,
                "Firmware status must be fully below the navigation title")
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        test.add(attachment)
        return data
    }
    func close() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        host = nil
        UIApplication.shared.isIdleTimerDisabled = originalIdleTimer
    }
}

private final class FirmwareFlowPeripheral: DFUPeripheral { let identifier = UUID() }
private final class FirmwareFlowDaemon: RuuviTagPropertiesDaemon {
    var starts = 0
    func start() { starts += 1 }
    func stop() {}
}
private final class FirmwareFlowActivity: ActivityPresenter {
    func show(with state: ActivityPresenterState, atPosition position: ActivityPresenterPosition) {}
    func update(with state: ActivityPresenterState) {}
    func dismiss(immediately: Bool) {}
}
private final class FirmwareFlowInteractor: DFUInteractorInput {
    let release = PassthroughSubject<LatestRelease, Error>()
    let download = PassthroughSubject<FirmwareDownloadResponse, Error>()
    let flash = PassthroughSubject<FlashResponse, Error>()
    let air = PassthroughSubject<Void, Error>()
    var loads = 0
    var downloads = 0
    var flashes = 0
    var waits = 0
    var lastFiles: [URL] = []
    var serves: [Future<CurrentRelease, Error>.Promise] = []
    var listeners: [Future<DFUDevice, Never>.Promise] = []
    var lost: [Future<String, Never>.Promise] = []
    func loadLatestRelease() -> AnyPublisher<LatestRelease, Error> {
        loads += 1
        return release.eraseToAnyPublisher()
    }
    func serveCurrentRelease(for ruuviTag: RuuviTagSensor) -> Future<CurrentRelease, Error> {
        Future { self.serves.append($0) }
    }
    func listen(ruuviTag: RuuviTagSensor) -> Future<DFUDevice, Never> { Future { self.listeners.append($0) } }
    func observeLost(uuid: String) -> Future<String, Never> { Future { self.lost.append($0) } }
    func download(release: LatestRelease, currentRelease: CurrentRelease?) -> AnyPublisher<
        FirmwareDownloadResponse, Error
    > {
        downloads += 1
        return download.eraseToAnyPublisher()
    }
    func waitForAirDevice(ruuviTag: RuuviTagSensor, timeout: TimeInterval) -> AnyPublisher<Void, Error> {
        waits += 1
        return air.eraseToAnyPublisher()
    }
    func flash(
        dfuDevice: DFUDevice, latestRelease: LatestRelease, currentRelease: CurrentRelease?,
        appUrl: URL, fullUrl: URL, additionalFiles: [URL]
    ) -> AnyPublisher<FlashResponse, Error> {
        flashes += 1
        lastFiles = [appUrl, fullUrl] + additionalFiles
        return flash.eraseToAnyPublisher()
    }
}

private enum FirmwareFlowWaitError: Error { case timeout }
@MainActor private func waitForFirmwareState(
    file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool
) async throws {
    for _ in 0..<200 {
        if condition() { return }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Timed out waiting for firmware state", file: file, line: line)
    throw FirmwareFlowWaitError.timeout
}
