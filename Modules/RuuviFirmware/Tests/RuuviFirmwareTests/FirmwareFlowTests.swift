import Combine
import Foundation
import SwiftUI
import XCTest
@testable import RuuviFirmware

@MainActor final class FirmwareFlowTests: XCTestCase {
    private var subscriptions = Set<AnyCancellable>()

    func testViewModelAndOutputAreReleasedWhenScreenCloses() async {
        let interactor = FirmwareInteractorSpy()
        var model: FirmwareViewModel? = .init(uuid: "sensor", currentFirmware: nil, interactor: interactor)
        var output: FirmwareOutputSpy? = .init()
        weak var weakModel = model
        weak var weakOutput = output
        model?.output = output
        output = nil
        XCTAssertNil(weakOutput)
        model = nil
        await Task.yield()
        XCTAssertNil(weakModel, "The Combine subscription must not retain its owner")
    }

    func testUpgradeFlowPublishesDownloadAndFlashProgressAndRendersEachStep() async throws {
        let interactor = FirmwareInteractorSpy()
        let model = FirmwareViewModel(uuid: "sensor", currentFirmware: nil, interactor: interactor)
        let release = GitHubRelease(version: "3.31.0", assets: [])
        let current = CurrentRelease(version: "3.30.0")
        let app = URL(fileURLWithPath: "/tmp/app.zip")
        let full = URL(fileURLWithPath: "/tmp/full.zip")
        model.send(event: .onAppear)
        try await state(model) { if case .loading = $0 { true } else { false } }
        interactor.releases.send(release)
        try await state(model) { if case .loaded = $0 { true } else { false } }
        model.send(event: .onLoaded(release))
        try await state(model) { if case .serving = $0 { true } else { false } }
        interactor.currentPromise?(.success(current))
        try await state(model) { if case .checking = $0 { true } else { false } }
        model.send(event: .onLoadedAndServed(release, current))
        try await state(model) { if case .isAbleToUpgrade = $0 { true } else { false } }
        model.send(event: .onStartUpgrade(release, current))
        try await state(model) { if case .downloading = $0 { true } else { false } }
        let progress = Progress(totalUnitCount: 100)
        progress.completedUnitCount = 50
        interactor.downloads.send(.progress(progress))
        let downloadProgress = expectation(description: "Download progress")
        model.$downloadProgress.filter { $0 == 0.5 }.first().sink { _ in downloadProgress.fulfill() }.store(
            in: &subscriptions)
        await fulfillment(of: [downloadProgress], timeout: 3)
        interactor.downloads.send(.response(appUrl: app, fullUrl: full))
        try await state(model) { if case .listening = $0 { true } else { false } }
        interactor.listenPromise?(.success("bootloader"))
        try await state(model) { if case .readyToUpdate = $0 { true } else { false } }
        model.send(event: .onUserDidConfirmToFlash(release, current, uuid: "bootloader", appUrl: app, fullUrl: full))
        try await state(model) { if case .flashing = $0 { true } else { false } }
        interactor.flashes.send(.progress(0.75))
        let flashProgress = expectation(description: "Flash progress")
        model.$flashProgress.filter { $0 == 0.75 }.first().sink { _ in flashProgress.fulfill() }.store(
            in: &subscriptions)
        await fulfillment(of: [flashProgress], timeout: 3)
        XCTAssertEqual(interactor.flashedUUID, "bootloader")
        interactor.flashes.send(.done)
        try await state(model) { if case .successfulyFlashed = $0 { true } else { false } }
        try render(model)
        let output = FirmwareOutputSpy()
        model.output = output
        model.finish()
        XCTAssertEqual(output.finished, 1)
        model.ensureBatteryHasEnoughPower(uuid: "sensor")
        model.restartPropertiesDaemon()
        interactor.batteryIsLow.send(true)
        XCTAssertTrue(model.isBatteryLow)
        XCTAssertEqual(interactor.checkedBatteries, ["sensor"])
        XCTAssertEqual(interactor.daemonRestarts, 1)
    }

    func testLoadingFailureAppearsInViewAndKnownFirmwareAvoidsBluetoothQuery() async throws {
        let interactor = FirmwareInteractorSpy()
        let model = FirmwareViewModel(uuid: "sensor", currentFirmware: "v3.31.0", interactor: interactor)
        model.send(event: .onAppear)
        try await state(model) { if case .loading = $0 { true } else { false } }
        interactor.releases.send(completion: .failure(URLError(.notConnectedToInternet)))
        try await state(model) { if case .error = $0 { true } else { false } }
        try render(model)
        let knownInteractor = FirmwareInteractorSpy()
        let known = FirmwareViewModel(uuid: "sensor", currentFirmware: "3.31.0", interactor: knownInteractor)
        let release = GitHubRelease(version: "3.31.0", assets: [])
        known.send(event: .onAppear)
        try await state(known) { if case .loading = $0 { true } else { false } }
        knownInteractor.releases.send(release)
        try await state(known) { if case .loaded = $0 { true } else { false } }
        known.send(event: .onLoaded(release))
        try await state(known) { if case .checking = $0 { true } else { false } }
        XCTAssertNil(knownInteractor.currentPromise)
        known.send(event: .onAppear)
        try await state(known) { if case .noNeedToUpgrade = $0 { true } else { false } }
        try render(known)
    }

    private func state(
        _ model: FirmwareViewModel, file: StaticString = #filePath, line: UInt = #line,
        matches: @escaping (FirmwareViewModel.State) -> Bool
    ) async throws {
        let reached = expectation(description: "Firmware state requested at line \(line)")
        let token = model.$state.filter(matches).first().sink { _ in reached.fulfill() }
        let result = await XCTWaiter.fulfillment(of: [reached], timeout: 3)
        token.cancel()
        guard result == .completed else {
            XCTFail("Unexpected firmware state: \(model.state)", file: file, line: line)
            throw NSError(domain: "FirmwareFlowTests", code: 1)
        }
    }

    private func render(_ model: FirmwareViewModel) throws {
        let renderer = ImageRenderer(content: FirmwareView(viewModel: model).frame(width: 402, height: 874))
        let image = try XCTUnwrap(renderer.uiImage)
        XCTAssertEqual(image.size, CGSize(width: 402, height: 874))
    }
}
