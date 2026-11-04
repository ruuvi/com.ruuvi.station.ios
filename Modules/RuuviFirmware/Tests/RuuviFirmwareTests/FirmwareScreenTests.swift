import Foundation
import SwiftUI
import XCTest
@testable import RuuviFirmware

@MainActor final class FirmwareScreenTests: XCTestCase {
    func testAllFirmwareStatesRenderAtPhoneSizeIncludingMissingVersionAndLowBattery() throws {
        let release = GitHubRelease(version: "3.31.0", assets: [])
        let app = URL(fileURLWithPath: "/tmp/app.zip")
        let full = URL(fileURLWithPath: "/tmp/full.zip")
        for current: CurrentRelease? in [nil, .init(version: "3.30.0")] {
            let states: [FirmwareViewModel.State] = [
                .idle, .loading, .loaded(release), .serving(release), .checking(release, current),
                .noNeedToUpgrade(release, current), .isAbleToUpgrade(release, current), .downloading(release, current),
                .listening(release, current, appUrl: app, fullUrl: full),
                .readyToUpdate(release, current, uuid: "boot", appUrl: app, fullUrl: full),
                .flashing(release, current, uuid: "boot", appUrl: app, fullUrl: full),
                .successfulyFlashed(release), .error(URLError(.timedOut)),
            ]
            for state in states {
                let interactor = FirmwareInteractorSpy()
                let model = FirmwareViewModel(
                    uuid: "sensor", currentFirmware: nil, interactor: interactor, initialState: state)
                interactor.batteryIsLow.send(current == nil)
                model.downloadProgress = 0.25
                model.flashProgress = 0.75
                let image = try XCTUnwrap(
                    ImageRenderer(content: FirmwareView(viewModel: model).frame(width: 402, height: 874)).uiImage)
                XCTAssertEqual(image.size, CGSize(width: 402, height: 874))
            }
        }
    }
}
