import AVFoundation
import CoreLocation
import PhotosUI
import RuuviCore
import RuuviPresenters
import UIKit
import XCTest
@testable import station

@MainActor final class PhotoPickerTests: XCTestCase {
    func testLibraryRequestsSingleImageSelectionAndCancellationDoesNotDeliverAPhoto() async throws {
        let controller = PhotoPresentationHost()
        let host = try AppViewHost(controller)
        defer { host.close() }
        let presenter = PhotoPickerPresenterSheet()
        let output = PhotoPickerOutputSpy()
        presenter.delegate = output
        await waitForAppState("photo host becomes active") {
            UIApplication.shared.topViewController() === controller && controller.view.window === host.window
        }
        presenter.showLibrary()
        let picker = try XCTUnwrap(controller.requestedPresentation as? PHPickerViewController)
        XCTAssertEqual(picker.configuration.selectionLimit, 1)
        XCTAssertEqual(picker.configuration.filter, .images)
        XCTAssertEqual(picker.configuration.preferredAssetRepresentationMode, .current)
        presenter.picker(picker, didFinishPicking: [])
        await flushAppBindings()
        XCTAssertTrue(output.photos.isEmpty)
    }

    func testCameraSelectionDeliversOnlyTheOriginalImageAfterDismissal() async {
        let presenter = PhotoPickerPresenterSheet()
        let output = PhotoPickerOutputSpy()
        presenter.delegate = output
        let picker = DismissingImagePicker()
        let image = makeImage()
        presenter.imagePickerController(picker, didFinishPickingMediaWithInfo: [.originalImage: image])
        XCTAssertEqual(picker.dismissals, 1)
        XCTAssertTrue(output.photos.first === image)
        presenter.imagePickerController(picker, didFinishPickingMediaWithInfo: [.mediaType: "invalid"])
        XCTAssertEqual(output.photos.count, 1)
    }

    func testImageProvidersDeliverOnMainAndUnsupportedOrFailedRepresentationsAreIgnored() async {
        let presenter = PhotoPickerPresenterSheet()
        let output = PhotoPickerOutputSpy()
        presenter.delegate = output
        presenter.loadSelectedImage(from: NSItemProvider(object: makeImage()))
        await waitForAppState("image provider loaded") { output.photos.count == 1 }
        XCTAssertTrue(output.onMain)
        let failed = NSItemProvider()
        let loaded = expectation(description: "failed provider was asked to load")
        failed.registerObject(ofClass: UIImage.self, visibility: .all) { completion in
            loaded.fulfill()
            completion(nil, NSError(domain: "Photo", code: 1))
            return nil
        }
        presenter.loadSelectedImage(from: failed)
        await fulfillment(of: [loaded], timeout: 2)
        presenter.loadSelectedImage(from: NSItemProvider(object: "Not an image" as NSString))
        await flushAppBindings()
        XCTAssertEqual(output.photos.count, 1)
    }

    func testAReleasedPresenterIsNotRetainedByAnOutstandingImageProvider() async {
        var presenter: PhotoPickerPresenterSheet? = PhotoPickerPresenterSheet()
        weak var released = presenter
        let output = PhotoPickerOutputSpy()
        presenter?.delegate = output
        let provider = NSItemProvider()
        let started = expectation(description: "provider suspended")
        var complete: ((NSItemProviderWriting?, Error?) -> Void)?
        provider.registerObject(ofClass: UIImage.self, visibility: .all) { callback in
            complete = callback
            started.fulfill()
            return nil
        }
        presenter?.loadSelectedImage(from: provider)
        await fulfillment(of: [started], timeout: 2)
        presenter = nil
        XCTAssertNil(released)
        complete?(makeImage(), nil)
        await flushAppBindings()
        XCTAssertTrue(output.photos.isEmpty)
    }

    func testDeniedCameraPermissionPresentsTheExplanationAndUnavailableCameraUsesLibrary() async throws {
        let controller = PhotoPresentationHost()
        let host = try AppViewHost(controller)
        defer { host.close() }
        let presenter = PhotoPickerPresenterSheet()
        let permissions = PhotoPermissionsSpy()
        let explanation = PhotoPermissionPresenterSpy()
        presenter.permissionsManager = permissions
        presenter.permissionPresenter = explanation
        presenter.showCameraUI()
        await waitForAppState("camera permission explanation") { explanation.cameraDenials == 1 }
        XCTAssertEqual(permissions.cameraRequests, 1)
        XCTAssertNil(controller.requestedPresentation)
        await waitForAppState("camera host becomes active") {
            UIApplication.shared.topViewController() === controller && controller.view.window === host.window
        }
        permissions.isCameraPermissionGranted = true
        presenter.isCameraAvailable = { false }
        presenter.showCameraUI()
        let picker = try XCTUnwrap(controller.requestedPresentation as? PHPickerViewController)
        XCTAssertEqual(picker.configuration.selectionLimit, 1)
        XCTAssertEqual(picker.configuration.filter, .images)
        XCTAssertEqual(permissions.cameraRequests, 1)
        await withCheckedContinuation { continuation in
            host.navigation.dismiss(animated: false) { continuation.resume() }
        }
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
    }
}
private final class PhotoPickerOutputSpy: PhotoPickerPresenterDelegate {
    var photos = [UIImage]()
    var onMain = true
    func photoPicker(presenter: PhotoPickerPresenter, didPick photo: UIImage) {
        onMain = onMain && Thread.isMainThread
        photos.append(photo)
    }
}
private final class DismissingImagePicker: UIImagePickerController {
    var dismissals = 0
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) { dismissals += 1; completion?() }
}
private final class PhotoPermissionsSpy: RuuviCorePermission {
    var isPhotoLibraryPermissionGranted = false
    var photoLibraryAuthorizationStatus: PHAuthorizationStatus = .denied
    var isCameraPermissionGranted = false
    var cameraAuthorizationStatus: AVAuthorizationStatus = .denied
    var isLocationPermissionGranted = false
    var locationAuthorizationStatus: CLAuthorizationStatus = .denied
    var cameraRequests = 0
    func requestPhotoLibraryPermission(completion: ((Bool) -> Void)?) { completion?(false) }
    func requestCameraPermission(completion: ((Bool) -> Void)?) { cameraRequests += 1; completion?(false) }
    func requestLocationPermission(completion: ((Bool) -> Void)?) { completion?(false) }
}
private final class PhotoPermissionPresenterSpy: PermissionPresenter {
    var cameraDenials = 0
    func presentNoPhotoLibraryPermission() {}
    func presentNoCameraPermission() { cameraDenials += 1 }
    func presentNoLocationPermission() {}
    func presentNoPushNotificationsPermission() {}
}

// Record the requested fallback without invoking the system camera or its permission UI.
private final class PhotoPresentationHost: UIViewController {
    var requestedPresentation: UIViewController?
    override func present(_ controller: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        requestedPresentation = controller
        completion?()
    }
}
