import Foundation
import RuuviDFU
import XCTest
@testable import station

final class FirmwareStateTests: XCTestCase {
    private let latest = LatestRelease(version: "3.10.0", assets: [])
    private let current = CurrentRelease(version: "3.9.0")
    private let app = URL(fileURLWithPath: "/firmware/app.bin")
    private let full = URL(fileURLWithPath: "/firmware/full.bin")
    private let files = [URL(fileURLWithPath: "/firmware/filesystem.bin")]

    func testUpgradeRequiresExplicitUserActionAndKeepsTheCheckedRelease() {
        let state = DFUViewModel.State.isAbleToUpgrade(latest, current)
        let unrelated: [DFUViewModel.Event] = [
            .onAppear, .onServed(nil), .onLoaded(latest),
            .onDownloading(latest, current, 0.5), .onDidFailLoading(URLError(.cancelled)),
        ]
        for event in unrelated {
            XCTAssertEqual(label(DFUViewModel.reduce(state, event)), "isAbleToUpgrade")
        }
        let other = LatestRelease(version: "99.0.0", assets: [])
        guard case let .downloading(release, installed) = DFUViewModel.reduce(state, .onStartUpgrade(other, nil)) else {
            return XCTFail("Explicit confirmation must begin the checked upgrade")
        }
        XCTAssertEqual(release.version, latest.version)
        XCTAssertEqual(installed?.version, current.version)
    }

    func testDownloadDiscoveryConfirmationAndCompletionPreserveFirmwareFiles() {
        let device = device()
        var state = DFUViewModel.reduce(
            .downloading(latest, current),
            .onDownloaded(latest, current, appUrl: app, fullUrl: full, additionalFiles: files))
        XCTAssertEqual(label(state), "listening")
        state = DFUViewModel.reduce(
            state,
            .onHeardRuuviBootDevice(
                latest, current, dfuDevice: device, appUrl: app, fullUrl: full, additionalFiles: files))
        XCTAssertEqual(label(state), "readyToUpdate")
        state = DFUViewModel.reduce(
            state,
            .onUserDidConfirmToFlash(
                latest, current, dfuDevice: device, appUrl: app, fullUrl: full, additionalFiles: files))
        guard case let .flashing(release, installed, target, appURL, fullURL, additional) = state else {
            return XCTFail("Expected flashing")
        }
        XCTAssertEqual(release.version, latest.version)
        XCTAssertEqual(installed?.version, current.version)
        XCTAssertEqual(target, device)
        XCTAssertEqual(appURL, app)
        XCTAssertEqual(fullURL, full)
        XCTAssertEqual(additional, files)
        state = DFUViewModel.reduce(state, .onSuccessfullyFlashedFirmware(latest))
        XCTAssertEqual(label(state), "successfulyFlashed")
        state = DFUViewModel.reduce(state, .onServingAfterUpdate(latest, current))
        XCTAssertEqual(label(state), "servingAfterUpdate")
        state = DFUViewModel.reduce(state, .onServedAfterUpdate(latest, .init(version: latest.version)))
        guard case let .firmwareAfterUpdate(release, installed) = state else {
            return XCTFail("Device firmware must be read after flashing")
        }
        XCTAssertEqual(release.version, installed?.version)
    }

    func testLostDeviceReturnsToListeningAndLateConfirmationCannotFlashAnotherDevice() {
        let target = device()
        let other = device()
        let ready = DFUViewModel.State.readyToUpdate(
            latest, current, dfuDevice: target, appUrl: app, fullUrl: full, additionalFiles: files)
        for event: DFUViewModel.Event in [
            .onLostRuuviBootDevice(
                latest, current, dfuDevice: other, appUrl: app, fullUrl: full, additionalFiles: files),
            .onUserDidConfirmToFlash(
                latest, current, dfuDevice: other, appUrl: app, fullUrl: full, additionalFiles: files),
        ] {
            XCTAssertEqual(label(DFUViewModel.reduce(ready, event)), "readyToUpdate")
        }
        let lost = DFUViewModel.reduce(
            ready,
            .onLostRuuviBootDevice(
                latest, current, dfuDevice: target, appUrl: app, fullUrl: full, additionalFiles: files))
        guard case let .listening(release, installed, appURL, fullURL, additional) = lost else {
            return XCTFail("Losing the selected device must return to discovery")
        }
        XCTAssertEqual(release.version, latest.version)
        XCTAssertEqual(installed?.version, current.version)
        XCTAssertEqual(appURL, app)
        XCTAssertEqual(fullURL, full)
        XCTAssertEqual(additional, files)
    }

    func testFailuresAfterFlashPreserveErrorAndTerminalStatesIgnoreLateCallbacks() {
        let target = device()
        let error = NSError(domain: "test-firmware", code: 7)
        let stages: [DFUViewModel.State] = [
            .flashing(latest, current, dfuDevice: target, appUrl: app, fullUrl: full, additionalFiles: files),
            .successfulyFlashed(latest), .servingAfterUpdate(latest),
        ]
        for stage in stages {
            guard case .error(let actual) = DFUViewModel.reduce(stage, .onDidFailFlashingFirmware(error)) else {
                return XCTFail("Firmware errors must leave the loading state")
            }
            XCTAssertEqual(actual as NSError, error)
        }
        let completed = DFUViewModel.reduce(
            .successfulyFlashed(latest), .onServedAfterUpdate(latest, .init(version: latest.version)))
        XCTAssertEqual(label(completed), "firmwareAfterUpdate")
        for terminal: DFUViewModel.State in [.error(error), completed, .noNeedToUpgrade(latest, current)] {
            XCTAssertEqual(label(DFUViewModel.reduce(terminal, .onAppear)), label(terminal))
            XCTAssertEqual(label(DFUViewModel.reduce(terminal, .onStartUpgrade(latest, current))), label(terminal))
        }
    }

    func testUnrelatedEventsDoNotAdvanceLoadingDiscoveryOrFlashing() {
        let target = device()
        let stages: [DFUViewModel.State] = [
            .idle, .loading, .serving(latest), .downloading(latest, current),
            .listening(latest, current, appUrl: app, fullUrl: full, additionalFiles: files),
            .readyToUpdate(latest, current, dfuDevice: target, appUrl: app, fullUrl: full, additionalFiles: files),
            .flashing(latest, current, dfuDevice: target, appUrl: app, fullUrl: full, additionalFiles: files),
            .servingAfterUpdate(latest),
        ]
        for stage in stages {
            XCTAssertEqual(
                label(DFUViewModel.reduce(stage, .onDownloading(latest, current, 0.5))), label(stage))
        }
        XCTAssertEqual(label(DFUViewModel.reduce(.loaded(latest), .onLoaded(latest))), "serving")
        XCTAssertEqual(label(DFUViewModel.reduce(.serving(latest), .onServed(current))), "checking")
    }

    func testStableReleaseReplacesDevelopmentBuildWithoutDowngradingNewerFirmware() {
        for version in ["3.10.0-dev", "3.10.0+DEV"] {
            XCTAssertTrue(
                DFUViewModel.isRecommendedToUpdate(
                    latestRelease: latest, currentRelease: .init(version: version)))
            XCTAssertFalse(
                DFUViewModel.isRecommendedToUpdate(
                    latestRelease: .init(version: version, assets: []), currentRelease: .init(version: version)))
        }
        XCTAssertFalse(
            DFUViewModel.isRecommendedToUpdate(
                latestRelease: latest, currentRelease: .init(version: "3.11.0-dev")))
        XCTAssertTrue(
            DFUViewModel.isRecommendedToUpdate(
                latestRelease: .init(version: "unknown", assets: []), currentRelease: current))
    }

    private func device() -> DFUDevice {
        let peripheral = FirmwareStatePeripheral()
        return .init(
            uuid: peripheral.identifier.uuidString, rssi: -50, isConnectable: true,
            name: "RuuviBoot", peripheral: peripheral)
    }

    private func label(_ state: DFUViewModel.State) -> String {
        switch state {
        case .idle: "idle"
        case .loading: "loading"
        case .loaded: "loaded"
        case .serving: "serving"
        case .checking: "checking"
        case .noNeedToUpgrade: "noNeedToUpgrade"
        case .isAbleToUpgrade: "isAbleToUpgrade"
        case .downloading: "downloading"
        case .listening: "listening"
        case .readyToUpdate: "readyToUpdate"
        case .flashing: "flashing"
        case .successfulyFlashed: "successfulyFlashed"
        case .servingAfterUpdate: "servingAfterUpdate"
        case .firmwareAfterUpdate: "firmwareAfterUpdate"
        case .error: "error"
        }
    }
}

private final class FirmwareStatePeripheral: DFUPeripheral {
    let identifier = UUID()
}
