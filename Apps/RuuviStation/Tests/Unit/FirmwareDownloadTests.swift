import Foundation
import XCTest
@testable import station

final class FirmwareDownloadTests: XCTestCase {
    func testFailedDownloadLeavesLoadingStateAndPreservesError() {
        let latest = LatestRelease(version: "3.10.0", assets: [])
        let error = NSError(domain: "firmware-download", code: 503)
        let state = DFUViewModel.reduce(.downloading(latest, nil), .onDidFailDownloading(error))
        guard case .error(let actual) = state else { return XCTFail("Download failure must be visible") }
        XCTAssertEqual((actual as NSError).domain, error.domain)
        XCTAssertEqual((actual as NSError).code, error.code)
    }

    func testLoadingFailureAndSuccessfulVersionCheck() {
        let latest = LatestRelease(version: "3.10.0", assets: [])
        guard case .loading = DFUViewModel.reduce(.idle, .onAppear) else { return XCTFail("Expected loading") }
        guard case .loaded = DFUViewModel.reduce(.loading, .onLoaded(latest)) else {
            return XCTFail("Expected release")
        }
        guard case .error = DFUViewModel.reduce(.loading, .onDidFailLoading(URLError(.timedOut))) else {
            return XCTFail("Expected loading error")
        }
        guard case .isAbleToUpgrade = DFUViewModel.reduce(.checking(latest, .init(version: "3.9.0")), .onAppear) else {
            return XCTFail("A newer numeric version must be offered")
        }
        guard case .noNeedToUpgrade = DFUViewModel.reduce(.checking(latest, .init(version: "3.10.0")), .onAppear) else {
            return XCTFail("Identical stable versions must not prompt an upgrade")
        }
    }

    func testVersionRecommendationHandlesMissingAndUnparseableVersions() {
        let release = LatestRelease(version: "3.10.0", assets: [])
        XCTAssertTrue(DFUViewModel.isRecommendedToUpdate(latestRelease: release, currentRelease: nil))
        XCTAssertTrue(
            DFUViewModel.isRecommendedToUpdate(latestRelease: release, currentRelease: .init(version: "unknown")))
        XCTAssertTrue(
            DFUViewModel.isRecommendedToUpdate(latestRelease: release, currentRelease: .init(version: "3.9.0")))
        XCTAssertFalse(
            DFUViewModel.isRecommendedToUpdate(latestRelease: release, currentRelease: .init(version: "4.0.0")))
        XCTAssertFalse(
            DFUViewModel.isRecommendedToUpdate(latestRelease: release, currentRelease: .init(version: "3.10.0")))
    }
}
