import RuuviLocal
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class BackgroundFixture {
    let measurements: MeasurementFixture
    let properties = AppSensorPropertiesSpy()
    let images = AppImagesSpy()
    let picker = AppPhotoPickerSpy()
    let errors = OffsetErrorSpy()
    let center = NotificationCenter()
    var presenter: BackgroundSelectionPresenter!
    let view: BackgroundSelectionViewController
    init(cloud: Bool = false, withoutSensor: Bool = false) throws {
        measurements = MeasurementFixture(cloud: cloud)
        presenter = BackgroundSelectionPresenter(ruuviTag: withoutSensor ? nil : measurements.sensor)
        presenter.notificationCenter = center
        presenter.ruuviSensorPropertiesService = properties
        presenter.ruuviLocalImages = images
        presenter.settings = measurements.settings
        presenter.errorPresenter = errors
        presenter.photoPickerPresenter = picker
        view = try XCTUnwrap(presenter.viewController as? BackgroundSelectionViewController)
    }
    var model: BackgroundSelectionViewModel { view.viewModel! }
    func progress(_ value: Double?, matching: Bool = true, local: Bool = false) {
        var info: [AnyHashable: Any] = [:]
        if local {
            info[BPDidUpdateBackgroundUploadProgressKey.luid] = matching ? measurements.sensor.luid! : "other".luid
        } else {
            info[BPDidUpdateBackgroundUploadProgressKey.macId] =
                matching ? measurements.sensor.macId! : "000000000000".mac
        }
        info[BPDidUpdateBackgroundUploadProgressKey.progress] = value
        center.post(name: .BackgroundPersistenceDidUpdateBackgroundUploadProgress, object: nil, userInfo: info)
    }
    func backgroundChanged(matching: Bool = true) {
        center.post(
            name: .BackgroundPersistenceDidChangeBackground, object: nil,
            userInfo: [
                BPDidChangeBackgroundKey.luid: matching ? measurements.sensor.luid! : "other".luid
            ])
    }
}

final class AppPhotoPickerSpy: PhotoPickerPresenter {
    weak var delegate: PhotoPickerPresenterDelegate?
    var cameras = 0
    var libraries = 0
    func showLibrary() { libraries += 1 }
    func showCameraUI() { cameras += 1 }
}

final class AppImagesSpy: RuuviLocalImages {
    var deletedProgress = [String]()
    func getOrGenerateBackground(for identifier: Identifier, ruuviDeviceType: RuuviDeviceType) -> UIImage? { nil }
    func getBackground(for identifier: Identifier) -> UIImage? { nil }
    func setBackground(_ id: Int, for identifier: Identifier) {}
    func setNextDefaultBackground(for identifier: Identifier) -> UIImage? { nil }
    func getCustomBackground(for identifier: Identifier) -> UIImage? { nil }
    func setCustomBackground(image: UIImage, compressionQuality: CGFloat, for identifier: Identifier)
        async throws(RuuviLocalError) -> URL
    { throw .failedToGetJpegRepresentation }
    func deleteCustomBackground(for uuid: Identifier) {}
    func backgroundUploadProgress(for identifier: Identifier) -> Double? { nil }
    func setBackgroundUploadProgress(percentage: Double, for identifier: Identifier) {}
    func deleteBackgroundUploadProgress(for identifier: Identifier) { deletedProgress.append(identifier.value) }
    func isPictureCached(for cloudSensor: CloudSensor) -> Bool { false }
    func setPictureIsCached(for cloudSensor: CloudSensor) {}
    func setPictureRemovedFromCache(for ruuviTag: RuuviTagSensor) {}
}
