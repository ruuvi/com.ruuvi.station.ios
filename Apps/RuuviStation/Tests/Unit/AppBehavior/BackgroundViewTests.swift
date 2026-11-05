import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class BackgroundViewTests: XCTestCase {
    func testDefaultPhotoGridRendersImagesAndRoutesAllSelectionActions() async throws {
        let fixture = try BackgroundFixture()
        let host = try AppViewHost(fixture.view, withBackStack: true)
        defer { host.close() }
        await flushAppBindings()
        let collection = try XCTUnwrap(fixture.view.view.allDescendants.compactMap { $0 as? UICollectionView }.first)
        collection.layoutIfNeeded()
        XCTAssertEqual(fixture.view.title, RuuviLocalization.changeBackground)
        XCTAssertEqual(collection.numberOfItems(inSection: 0), 17)
        let first = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 0, section: 0)))
        XCTAssertNotNil(first.allDescendants.compactMap { $0 as? UIImageView }.first?.image)
        XCTAssertGreaterThan(first.frame.width, 0)
        let header = try XCTUnwrap(collection.allDescendants.compactMap { $0 as? BackgroundSelectionViewHeader }.first)
        header.didTapButton(header.takePhotoButton)
        header.didTapButton(header.selectFromGalleryButton)
        XCTAssertEqual(fixture.picker.cameras, 1)
        XCTAssertEqual(fixture.picker.libraries, 1)
        collection.scrollToItem(at: IndexPath(item: 16, section: 0), at: .bottom, animated: false)
        collection.layoutIfNeeded()
        let last = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 16, section: 0)))
        XCTAssertNotNil(last.allDescendants.compactMap { $0 as? UIImageView }.first?.image)
        fixture.view.collectionView(collection, didSelectItemAt: IndexPath(item: 16, section: 0))
        await waitForAppState("selected default uploaded") { fixture.properties.imageWrites.count == 1 }
        XCTAssertTrue(fixture.properties.imageWrites.first?.1 === fixture.model.defaultImages.value?.last?.image)
    }

    func testUploadProgressShowsPercentageAndCancelHidesIt() async throws {
        let fixture = try BackgroundFixture(cloud: true)
        let host = try AppViewHost(fixture.view)
        defer { host.close() }
        let progress = try XCTUnwrap(
            fixture.view.view.allDescendants.compactMap { $0 as? BackgroundSelectionUploadProgressView }.first)
        await flushAppBindings()
        XCTAssertTrue(progress.isHidden)
        fixture.progress(0.45)
        await flushAppBindings()
        XCTAssertFalse(progress.isHidden)
        XCTAssertEqual(progress.progressLabel.text, RuuviLocalization.uploadingProgress(45))
        fixture.view.didTapCancel()
        await flushAppBindings()
        XCTAssertTrue(progress.isHidden)
        XCTAssertEqual(fixture.images.deletedProgress, [fixture.measurements.sensor.macId!.value])
    }

    func testLocalImageSaveReturnsToPreviousScreenAndCloudWaitsForUploadCompletion() async throws {
        for cloud in [false, true] {
            let fixture = try BackgroundFixture(cloud: cloud)
            let host = try AppViewHost(fixture.view, withBackStack: true)
            defer { host.close() }
            fixture.properties.images[fixture.measurements.sensor.id] = UIImage(systemName: "photo")!
            fixture.backgroundChanged()
            await waitForAppState("new background read") { fixture.model.background.value != nil }
            if cloud {
                XCTAssertTrue(host.navigation.topViewController === fixture.view)
                fixture.progress(1)
            }
            await waitForAppState("returned from background chooser") {
                host.navigation.topViewController !== fixture.view
            }
            fixture.backgroundChanged()
            await flushAppBindings()
            XCTAssertEqual(host.navigation.viewControllers.count, 1)
        }
    }
}
