import UIKit
import XCTest
@testable import station

@MainActor final class BackgroundLifecycleTests: XCTestCase {
    func testRepeatedViewLoadingDoesNotMultiplyBackgroundObservers() async throws {
        let fixture = try BackgroundFixture()
        fixture.properties.images[fixture.measurements.sensor.id] = UIImage(systemName: "photo")!
        fixture.presenter.viewDidLoad()
        fixture.presenter.viewDidLoad()
        fixture.backgroundChanged()
        await waitForAppState("background read") { !fixture.properties.imageReads.isEmpty }
        await flushAppBindings()
        XCTAssertEqual(fixture.properties.imageReads.count, 1)
    }

    func testClosingDuringAnImageReadReleasesPresenterAndIgnoresTheLateResult() async throws {
        let fixture = try BackgroundFixture()
        var release: CheckedContinuation<Void, Never>?
        fixture.properties.images[fixture.measurements.sensor.id] = UIImage(systemName: "photo")!
        fixture.properties.beforeImage = { await withCheckedContinuation { release = $0 } }
        fixture.presenter.viewDidLoad()
        fixture.backgroundChanged()
        await waitForAppState("image read pending") { release != nil }
        weak var presenter = fixture.presenter
        fixture.view.output = nil
        fixture.presenter = nil
        XCTAssertNil(presenter)
        release?.resume(); release = nil
        await flushAppBindings(); await flushAppBindings()
        XCTAssertNil(fixture.model.background.value)
        fixture.backgroundChanged()
        await flushAppBindings()
        XCTAssertEqual(fixture.properties.imageReads.count, 1)
    }

    func testCancelledUploadCannotReplaceTheDisplayedPhotoWhenItsRequestReturns() async throws {
        let fixture = try BackgroundFixture()
        var release: CheckedContinuation<Void, Never>?
        fixture.properties.beforeSetImage = { await withCheckedContinuation { release = $0 } }
        let photo = UIImage(systemName: "photo")!
        fixture.presenter.photoPicker(presenter: fixture.picker, didPick: photo)
        await waitForAppState("upload pending") { release != nil }
        fixture.presenter.viewDidCancelUpload()
        release?.resume(); release = nil
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.model.isUploadingBackground.value, false)
        XCTAssertNil(fixture.model.background.value)
        XCTAssertTrue(fixture.errors.errors.isEmpty)
    }

    func testChoosingAnotherPhotoIgnoresThePreviousUploadAndResetsItsProgress() async throws {
        let fixture = try BackgroundFixture()
        var release: CheckedContinuation<Void, Never>?
        fixture.properties.beforeSetImage = {
            if fixture.properties.imageWrites.count == 1 { await withCheckedContinuation { release = $0 } }
        }
        let first = UIImage(systemName: "photo")!
        let second = UIImage(systemName: "sun.max")!
        fixture.presenter.viewDidLoad()
        fixture.presenter.photoPicker(presenter: fixture.picker, didPick: first)
        await waitForAppState("first upload waiting") { release != nil }
        fixture.progress(0.8)
        fixture.presenter.photoPicker(presenter: fixture.picker, didPick: second)
        XCTAssertEqual(fixture.model.uploadingBackgroundPercentage.value, 0)
        await waitForAppState("second photo shown") { fixture.model.background.value === second }
        release?.resume(); release = nil
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.model.background.value === second)
    }
}
