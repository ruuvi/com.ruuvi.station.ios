import UIKit
import XCTest
@testable import station

@MainActor final class BackgroundPresenterTests: XCTestCase {
    func testDefaultImagesAreOrderedAndCameraAndGalleryUseTheirPicker() throws {
        let fixture = try BackgroundFixture()
        XCTAssertTrue(fixture.presenter.viewController === fixture.view)
        XCTAssertEqual(fixture.model.defaultImages.value?.map(\.id), Array((1...17).reversed()))
        XCTAssertTrue(fixture.model.defaultImages.value?.allSatisfy { $0.image != nil && $0.thumbnail != nil } == true)
        fixture.presenter.viewDidAskToSelectCamera()
        fixture.presenter.viewDidAskToSelectGallery()
        XCTAssertEqual(fixture.picker.cameras, 1)
        XCTAssertEqual(fixture.picker.libraries, 1)
        XCTAssertTrue(fixture.picker.delegate === fixture.presenter)
    }

    func testDefaultAndPickedPhotosUseConfiguredSizeAndQualityAndUpdateTheBackground() async throws {
        let fixture = try BackgroundFixture()
        fixture.measurements.settings.imageCompressionQuality = 65
        let image = UIImage(systemName: "tree")!
        fixture.presenter.viewDidSelectDefaultPhoto(model: .init(id: 99, image: image, thumbnail: image))
        XCTAssertEqual(fixture.model.isUploadingBackground.value, true)
        await waitForAppState("background uploaded") { fixture.model.isUploadingBackground.value == false }
        XCTAssertEqual(fixture.properties.imageWrites.count, 1)
        XCTAssertEqual(fixture.properties.imageWrites.first?.0, fixture.measurements.sensor.id)
        XCTAssertEqual(fixture.properties.imageWrites.first?.2, CGSize(width: 3000, height: 3000))
        XCTAssertEqual(fixture.properties.imageWrites.first?.3, 0.65)
        XCTAssertTrue(fixture.model.background.value === image)
        let photo = UIImage(systemName: "sun.max")!
        fixture.presenter.photoPicker(presenter: fixture.picker, didPick: photo)
        await waitForAppState("picked photo uploaded") { fixture.model.background.value === photo }
        XCTAssertEqual(fixture.properties.imageWrites.count, 2)
    }

    func testMissingImageOrSensorDoesNotUploadAndErrorsStopTheProgressIndicator() async throws {
        let empty = try BackgroundFixture(withoutSensor: true)
        let photo = UIImage(systemName: "photo")!
        empty.presenter.viewDidSelectDefaultPhoto(model: .init(id: 1, image: photo, thumbnail: photo))
        empty.presenter.photoPicker(presenter: empty.picker, didPick: photo)
        empty.presenter.viewDidCancelUpload()
        XCTAssertTrue(empty.images.deletedProgress.isEmpty)
        let fixture = try BackgroundFixture()
        fixture.presenter.viewDidSelectDefaultPhoto(model: .init(id: 1, image: nil, thumbnail: nil))
        await flushAppBindings()
        XCTAssertTrue(fixture.properties.imageWrites.isEmpty)
        XCTAssertTrue(empty.properties.imageWrites.isEmpty)
        fixture.properties.failure = .failedToGetJpegRepresentation
        fixture.presenter.photoPicker(presenter: fixture.picker, didPick: photo)
        await waitForAppState("photo failure") { fixture.errors.errors.count == 1 }
        XCTAssertEqual(fixture.model.isUploadingBackground.value, false)
        XCTAssertNil(fixture.model.background.value)
    }

    func testProgressFiltersOtherSensorsAndCancellationRemovesPersistedProgress() throws {
        let fixture = try BackgroundFixture(cloud: true)
        fixture.presenter.viewDidLoad()
        fixture.progress(0.25, matching: false)
        XCTAssertNil(fixture.model.uploadingBackgroundPercentage.value)
        fixture.progress(0.4)
        XCTAssertEqual(fixture.model.uploadingBackgroundPercentage.value, 0.4)
        XCTAssertEqual(fixture.model.isUploadingBackground.value, true)
        fixture.progress(0.7, local: true)
        XCTAssertEqual(fixture.model.uploadingBackgroundPercentage.value, 0.7)
        fixture.progress(nil)
        XCTAssertNil(fixture.model.uploadingBackgroundPercentage.value)
        XCTAssertEqual(fixture.model.isUploadingBackground.value, false)
        fixture.progress(1)
        XCTAssertEqual(fixture.model.isUploadingBackground.value, false)
        fixture.presenter.viewDidCancelUpload()
        XCTAssertNil(fixture.model.uploadingBackgroundPercentage.value)
        XCTAssertEqual(fixture.images.deletedProgress, [fixture.measurements.sensor.macId!.value])
    }

    func testBackgroundNotificationsRefreshOnlyTheMatchingSensorAndReportReadErrors() async throws {
        let fixture = try BackgroundFixture(cloud: true)
        let photo = UIImage(systemName: "photo")!
        fixture.properties.images[fixture.measurements.sensor.id] = photo
        fixture.presenter.viewDidLoad()
        fixture.backgroundChanged(matching: false)
        await flushAppBindings()
        XCTAssertTrue(fixture.properties.imageReads.isEmpty)
        fixture.backgroundChanged()
        await waitForAppState("background refreshed") { fixture.model.background.value === photo }
        fixture.properties.failure = .failedToGetJpegRepresentation
        fixture.backgroundChanged()
        await waitForAppState("background read failed") { fixture.errors.errors.count == 1 }
        XCTAssertTrue(fixture.model.background.value === photo)
    }
}
