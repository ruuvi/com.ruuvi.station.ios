import Foundation
import XCTest
@testable import RuuviFirmware

final class RuuviFirmwareTests: XCTestCase {
    func testFailedDownloadLeavesLoadingStateAndPreservesError() {
        let latest = GitHubRelease(version: "3.10.0", assets: [])
        let error = NSError(domain: "firmware-download", code: 503)
        let state = FirmwareViewModel.reduce(.downloading(latest, nil), .onDidFailDownloading(error))
        guard case .error(let actual) = state else { return XCTFail("Download failure must be visible") }
        XCTAssertEqual((actual as NSError).domain, error.domain)
        XCTAssertEqual((actual as NSError).code, error.code)
    }

    func testLoadingFailureAndSuccessfulVersionCheck() {
        let latest = GitHubRelease(version: "3.10.0", assets: [])
        guard case .loading = FirmwareViewModel.reduce(.idle, .onAppear) else { return XCTFail("Expected loading") }
        guard case .loaded = FirmwareViewModel.reduce(.loading, .onLoaded(latest)) else {
            return XCTFail("Expected release")
        }
        guard case .error = FirmwareViewModel.reduce(.loading, .onDidFailLoading(URLError(.timedOut))) else {
            return XCTFail("Expected loading error")
        }
        guard case .isAbleToUpgrade = FirmwareViewModel.reduce(.checking(latest, .init(version: "3.9.0")), .onAppear)
        else {
            return XCTFail("A newer numeric version must be offered")
        }
        guard case .noNeedToUpgrade = FirmwareViewModel.reduce(.checking(latest, .init(version: "3.10.0")), .onAppear)
        else {
            return XCTFail("Identical stable versions must not prompt an upgrade")
        }
    }

    func testVersionRecommendationHandlesMissingAndUnparseableVersions() {
        let release = GitHubRelease(version: "3.10.0", assets: [])
        XCTAssertTrue(FirmwareViewModel.isRecommendedToUpdate(latestRelease: release, currentRelease: nil))
        XCTAssertTrue(
            FirmwareViewModel.isRecommendedToUpdate(latestRelease: release, currentRelease: .init(version: "unknown")))
        XCTAssertTrue(
            FirmwareViewModel.isRecommendedToUpdate(latestRelease: release, currentRelease: .init(version: "3.9.0")))
        XCTAssertFalse(
            FirmwareViewModel.isRecommendedToUpdate(latestRelease: release, currentRelease: .init(version: "4.0.0")))
        XCTAssertFalse(
            FirmwareViewModel.isRecommendedToUpdate(latestRelease: release, currentRelease: .init(version: "3.10.0")))
    }
}
