import Foundation
import RuuviOntology
import RuuviService
import RuuviPresenters
import RuuviLocal
import UIKit

final class BackgroundSelectionPresenter: BackgroundSelectionModuleInput {
    var viewController: UIViewController {
        if let view = self.weakView {
            return view
        } else {
            let view = BackgroundSelectionViewController()
            view.output = self
            view.viewModel = self.viewModel
            self.weakView = view
            return view
        }

    }
    private weak var weakView: UIViewController?
    private let ruuviTag: RuuviTagSensor?
    private let virtualSensor: VirtualTagSensor?
    private var viewModel: BackgroundSelectionViewModel! {
        didSet {
            prepareDefaultImages()
        }
    }
    private var backgroundUploadProgressToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    // TODO: Find out why backgroundToken is getting notification twice.
    /// A boolean to keep track of background upload for local sensors
    private var didUploadBackground: Bool = false

    var photoPickerPresenter: PhotoPickerPresenter! {
        didSet {
            photoPickerPresenter.delegate = self
        }
    }
    var ruuviSensorPropertiesService: RuuviServiceSensorProperties!
    var ruuviLocalImages: RuuviLocalImages!
    var errorPresenter: ErrorPresenter!

    init(ruuviTag: RuuviTagSensor?,
         virtualSensor: VirtualTagSensor?) {
        self.ruuviTag = ruuviTag
        self.virtualSensor = virtualSensor

        // swiftlint:disable:next inert_defer
        defer { self.viewModel = BackgroundSelectionViewModel() }
    }
}

extension BackgroundSelectionPresenter: BackgroundSelectionViewOutput {
    func viewDidLoad() {
        startSubscribeToBackgroundUploadProgressChanges()
    }

    func viewDidAskToSelectCamera() {
        photoPickerPresenter.showCameraUI()
    }

    func viewDidAskToSelectGallery() {
        photoPickerPresenter.showLibrary()
    }

    func viewDidSelectDefaultPhoto(model: DefaultBackgroundModel) {
        if let photo = model.image {
            if let ruuviTag = ruuviTag {
                performPhotoUpload(with: photo, ruuviTag: ruuviTag)
            } else if let virtualSensor = virtualSensor {
                performPhotoUpload(with: photo, virtualSensor: virtualSensor)
            }
        }
    }

    func viewDidCancelUpload() {
        viewModel.isUploadingBackground.value = false
        viewModel.uploadingBackgroundPercentage.value = nil
        if let macId = ruuviTag?.macId {
            ruuviLocalImages.deleteBackgroundUploadProgress(for: macId)
        }
    }
}

extension BackgroundSelectionPresenter {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func startSubscribeToBackgroundUploadProgressChanges() {
        backgroundUploadProgressToken = NotificationCenter
            .default
            .addObserver(forName: .BackgroundPersistenceDidUpdateBackgroundUploadProgress,
                         object: nil,
                         queue: .main) { [weak self] notification in
                guard let sSelf = self else { return }
                if let userInfo = notification.userInfo, let ruuviTag = sSelf.ruuviTag {
                    let luid = userInfo[BPDidUpdateBackgroundUploadProgressKey.luid] as? LocalIdentifier
                    let macId = userInfo[BPDidUpdateBackgroundUploadProgressKey.macId] as? MACIdentifier
                    if (ruuviTag.luid?.value != nil && ruuviTag.luid?.value == luid?.value)
                        || (ruuviTag.macId?.value != nil && ruuviTag.macId?.value == macId?.value) {
                        if let percentage = userInfo[BPDidUpdateBackgroundUploadProgressKey.progress] as? Double {
                            sSelf.viewModel.uploadingBackgroundPercentage.value = percentage
                            sSelf.viewModel.isUploadingBackground.value = percentage < 1.0
                            if percentage == 1.0 {
                                if let weakView = sSelf.weakView as? BackgroundSelectionViewController {
                                    weakView.viewShouldDismiss()
                                }
                            }
                        } else {
                            sSelf.viewModel.uploadingBackgroundPercentage.value = nil
                            sSelf.viewModel.isUploadingBackground.value = false
                        }
                    }
                }
            }
        backgroundToken = NotificationCenter
            .default
            .addObserver(forName: .BackgroundPersistenceDidChangeBackground,
                         object: nil,
                         queue: .main) { [weak self] notification in

                guard let sSelf = self else { return }
                if let userInfo = notification.userInfo, let ruuviTag = sSelf.ruuviTag {
                    let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier
                    let macId = userInfo[BPDidChangeBackgroundKey.macId] as? MACIdentifier
                    if (ruuviTag.luid?.value != nil && ruuviTag.luid?.value == luid?.value)
                        || (ruuviTag.macId?.value != nil && ruuviTag.macId?.value == macId?.value) {
                        sSelf.ruuviSensorPropertiesService.getImage(for: ruuviTag)
                            .on(success: { [weak sSelf] image in
                                guard let sSelf = sSelf else { return }
                                sSelf.viewModel.background.value = image
                                var isLocalSensor: Bool = true
                                if let isCloudSensor = sSelf.ruuviTag?.isCloudSensor {
                                    isLocalSensor = !isCloudSensor
                                }

                                if isLocalSensor && !sSelf.didUploadBackground {
                                    sSelf.didUploadBackground = true
                                    if let weakView = sSelf.weakView as? BackgroundSelectionViewController {
                                        weakView.viewShouldDismiss()
                                    }
                                }
                            }, failure: { [weak sSelf] error in
                                sSelf?.errorPresenter.present(error: error)
                            })
                    }
                }
            }
    }

    private func prepareDefaultImages() {
        var defaultImages: [DefaultBackgroundModel] = []
        for i in (1...16).reversed() {
            let image = UIImage(named: "bg\(i)")
            let model = DefaultBackgroundModel(id: i,
                                               image: image,
                                               thumbnail: image.resize())
            defaultImages.append(model)
        }
        viewModel.defaultImages.value = defaultImages
    }
}

extension BackgroundSelectionPresenter: PhotoPickerPresenterDelegate {
    func photoPicker(presenter: PhotoPickerPresenter, didPick photo: UIImage) {
        if let ruuviTag = ruuviTag {
            performPhotoUpload(with: photo, ruuviTag: ruuviTag)
        } else if let virtualSensor = virtualSensor {
            performPhotoUpload(with: photo, virtualSensor: virtualSensor)
        }
    }

    private func performPhotoUpload(with photo: UIImage, ruuviTag: RuuviTagSensor) {
        viewModel.isUploadingBackground.value = true
        ruuviSensorPropertiesService.set(
            image: photo,
            for: ruuviTag
        ).on(success: { [weak self] _ in
            self?.viewModel.isUploadingBackground.value = false
            self?.viewModel.background.value = photo
        }, failure: { [weak self] error in
            self?.viewModel.isUploadingBackground.value = false
            self?.errorPresenter.present(error: error)
        })
    }

    private func performPhotoUpload(with photo: UIImage, virtualSensor: VirtualTagSensor) {
        ruuviSensorPropertiesService.set(image: photo, for: virtualSensor)
            .on(success: { [weak self] _ in
                self?.viewModel.background.value = photo
                if let weakView = self?.weakView as? BackgroundSelectionViewController {
                    weakView.viewShouldDismiss()
                }
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
    }
}
