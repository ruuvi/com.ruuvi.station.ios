import Foundation
import XCTest
@testable import RuuviFirmware

final class FirmwareTransitionTests: XCTestCase {
    private let latest = GitHubRelease(version: "3.31.0", assets: [])
    private let current = CurrentRelease(version: "3.30.0")
    private let app = URL(fileURLWithPath: "/tmp/application.zip")
    private let full = URL(fileURLWithPath: "/tmp/full.zip")

    func testCompleteUpgradeAndLostBootloaderKeepReleaseAndDownloadIdentity() {
        var state = FirmwareViewModel.reduce(.loaded(latest), .onAppear)
        guard case .serving(let release) = state else { return XCTFail("Expected firmware revision query") }
        XCTAssertEqual(release.version, latest.version)
        state = FirmwareViewModel.reduce(state, .onServed(current))
        guard case .checking(let release, let current) = state else { return XCTFail("Expected version check") }
        XCTAssertEqual(release.version, latest.version)
        XCTAssertEqual(current?.version, self.current.version)
        state = FirmwareViewModel.reduce(state, .onLoadedAndServed(latest, current))
        guard case .isAbleToUpgrade = state else { return XCTFail("Upgrade should be available") }
        state = FirmwareViewModel.reduce(state, .onStartUpgrade(latest, current))
        guard case .downloading = state else { return XCTFail("Expected downloads") }
        state = FirmwareViewModel.reduce(state, .onDownloaded(latest, current, appUrl: app, fullUrl: full))
        assertListening(state)
        let heard = FirmwareViewModel.Event.onHeardRuuviBootDevice(
            latest, current, uuid: "bootloader", appUrl: app, fullUrl: full)
        state = FirmwareViewModel.reduce(state, heard)
        guard case .readyToUpdate(_, _, let uuid, let appURL, let fullURL) = state else {
            return XCTFail("Expected confirmation")
        }
        XCTAssertEqual(uuid, "bootloader")
        XCTAssertEqual(appURL, app)
        XCTAssertEqual(fullURL, full)
        state = FirmwareViewModel.reduce(
            state, .onLostRuuviBootDevice(latest, current, uuid: uuid, appUrl: app, fullUrl: full))
        assertListening(state)
        state = FirmwareViewModel.reduce(state, heard)
        state = FirmwareViewModel.reduce(
            state, .onUserDidConfirmToFlash(latest, current, uuid: uuid, appUrl: app, fullUrl: full))
        guard case .flashing = state else { return XCTFail("Expected flashing after confirmation") }
        state = FirmwareViewModel.reduce(state, .onSuccessfullyFlashedFirmware(latest))
        guard case .successfulyFlashed(let flashed) = state else { return XCTFail("Expected completion") }
        XCTAssertEqual(flashed.version, latest.version)
        guard case .successfulyFlashed = FirmwareViewModel.reduce(state, .onAppear) else {
            return XCTFail("Success must remain visible")
        }
    }

    func testOutOfOrderEventsCannotStartFlashingOrDismissTerminalState() {
        let ignored = FirmwareViewModel.Event.onServedAfterUpdate(current)
        let states: [FirmwareViewModel.State] = [
            .idle, .loading, .serving(latest), .noNeedToUpgrade(latest, current), .downloading(latest, current),
            .listening(latest, current, appUrl: app, fullUrl: full),
            .readyToUpdate(latest, current, uuid: "boot", appUrl: app, fullUrl: full),
            .flashing(latest, current, uuid: "boot", appUrl: app, fullUrl: full),
            .error(URLError(.timedOut)),
        ]
        for state in states {
            XCTAssertEqual(caseName(FirmwareViewModel.reduce(state, ignored)), caseName(state))
        }
        let error = NSError(domain: "dfu", code: 42)
        let failed = FirmwareViewModel.reduce(
            .flashing(latest, current, uuid: "boot", appUrl: app, fullUrl: full),
            .onDidFailFlashingFirmware(error))
        guard case .error(let actual) = failed else { return XCTFail("Expected flash error") }
        XCTAssertEqual((actual as NSError).domain, "dfu")
        XCTAssertEqual((actual as NSError).code, 42)
    }

    func testVersionParserHandlesUnicodePrefixesAndRejectsIncompleteOrOverflowingVersions() {
        XCTAssertEqual("🌿 Ruuvi FW v3.31.0-beta".semVar, [3, 31, 0])
        XCTAssertEqual("01.002.0003".semVar, [1, 2, 3])
        XCTAssertNil("3.31".semVar)
        XCTAssertNil("unknown".semVar)
        XCTAssertNil("999999999999999999999999999999.1.0".semVar)
        XCTAssertTrue(
            FirmwareViewModel.isRecommendedToUpdate(
                latestRelease: .init(version: "unknown", assets: []), currentRelease: current))
    }

    func testGitHubReleaseDecodesRealAPIKeysAndSelectsOnlyDefaultZipAssets() throws {
        let data = Data("""
            {"tag_name":"v3.31.0","assets":[
                {"name":"default.txt","browser_download_url":"https://example.com/readme"},
                {"name":"custom_app.zip","browser_download_url":"https://example.com/custom"},
                {"name":"ruuvi_default_app.zip","browser_download_url":"https://example.com/app.zip"},
                {"name":"ruuvi_default.zip","browser_download_url":"https://example.com/full.zip"}
            ]}
            """.utf8)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        XCTAssertEqual(release.version, "v3.31.0")
        XCTAssertEqual(release.defaultAppZipName, "ruuvi_default_app.zip")
        XCTAssertEqual(release.defaultFullZipName, "ruuvi_default.zip")
        XCTAssertEqual(release.defaultAppZipUrl?.absoluteString, "https://example.com/app.zip")
        XCTAssertEqual(release.defaultFullZipUrl?.absoluteString, "https://example.com/full.zip")
        let encoded = try JSONEncoder().encode(release)
        let roundTrip = try JSONDecoder().decode(GitHubRelease.self, from: encoded)
        XCTAssertEqual(roundTrip.assets.map(\.name), release.assets.map(\.name))
        XCTAssertNil(latest.defaultAppZipName)
        XCTAssertNil(latest.defaultAppZipUrl)
        XCTAssertNil(latest.defaultFullZipName)
        XCTAssertNil(latest.defaultFullZipUrl)
    }

    private func assertListening(_ state: FirmwareViewModel.State, file: StaticString = #filePath, line: UInt = #line) {
        guard case .listening(let release, let current, let appURL, let fullURL) = state else {
            return XCTFail("Expected bootloader scanning", file: file, line: line)
        }
        XCTAssertEqual(release.version, latest.version, file: file, line: line)
        XCTAssertEqual(current?.version, self.current.version, file: file, line: line)
        XCTAssertEqual(appURL, app, file: file, line: line)
        XCTAssertEqual(fullURL, full, file: file, line: line)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func caseName(_ state: FirmwareViewModel.State) -> String {
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
        case .successfulyFlashed: "success"
        case .error: "error"
        }
    }
}
