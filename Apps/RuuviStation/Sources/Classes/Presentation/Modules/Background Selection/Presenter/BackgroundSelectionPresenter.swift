import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPresenters
import RuuviService
import UIKit

final class BackgroundSelectionPresenter: BackgroundSelectionModuleInput {
    var notificationCenter: NotificationCenter = .default
    var viewController: UIViewController {
        if let weakView { return weakView }
        let view = BackgroundSelectionViewController()
        view.output = self
        view.viewModel = viewModel
        weakView = view
        return view
    }

    private weak var weakView: BackgroundSelectionViewController?
    private let ruuviTag: RuuviTagSensor?
    private var viewModel = BackgroundSelectionViewModel()
    private var backgroundUploadProgressToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    private var observerCenter: NotificationCenter?
    private var imageTask: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?
    private var didUploadBackground = false
    private let maxSize = CGSize(width: 3000, height: 3000)

    var photoPickerPresenter: PhotoPickerPresenter! {
        didSet { photoPickerPresenter.delegate = self }
    }
    var ruuviSensorPropertiesService: RuuviServiceSensorProperties!
    var ruuviLocalImages: RuuviLocalImages!
    var settings: RuuviLocalSettings!
    var errorPresenter: ErrorPresenter!

    init(ruuviTag: RuuviTagSensor?) {
        self.ruuviTag = ruuviTag
        prepareDefaultImages()
    }

    deinit {
        if let backgroundToken { observerCenter?.removeObserver(backgroundToken) }
        if let backgroundUploadProgressToken { observerCenter?.removeObserver(backgroundUploadProgressToken) }
        imageTask?.cancel()
        uploadTask?.cancel()
    }
}

extension BackgroundSelectionPresenter: BackgroundSelectionViewOutput {
    func viewDidLoad() {
        if let backgroundToken { observerCenter?.removeObserver(backgroundToken) }
        if let backgroundUploadProgressToken { observerCenter?.removeObserver(backgroundUploadProgressToken) }
        observerCenter = notificationCenter
        backgroundUploadProgressToken = notificationCenter.addObserver(
            forName: .BackgroundPersistenceDidUpdateBackgroundUploadProgress, object: nil, queue: .main
        ) { [weak self] notification in self?.updateProgress(notification) }
        backgroundToken = notificationCenter.addObserver(
            forName: .BackgroundPersistenceDidChangeBackground, object: nil, queue: .main
        ) { [weak self] notification in self?.refreshBackground(notification) }
    }

    func viewDidAskToSelectCamera() { photoPickerPresenter.showCameraUI() }
    func viewDidAskToSelectGallery() { photoPickerPresenter.showLibrary() }

    func viewDidSelectDefaultPhoto(model: DefaultBackgroundModel) {
        guard let photo = model.image, let ruuviTag else { return }
        performPhotoUpload(with: photo, ruuviTag: ruuviTag)
    }

    func viewDidCancelUpload() {
        uploadTask?.cancel()
        imageTask?.cancel()
        viewModel.isUploadingBackground.value = false
        viewModel.uploadingBackgroundPercentage.value = nil
        if let macId = ruuviTag?.macId { ruuviLocalImages.deleteBackgroundUploadProgress(for: macId) }
    }
}

private extension BackgroundSelectionPresenter {
    func matches(luid: LocalIdentifier?, macId: MACIdentifier?) -> Bool {
        guard let ruuviTag else { return false }
        return (ruuviTag.luid != nil && ruuviTag.luid?.value == luid?.value)
            || (ruuviTag.macId != nil && ruuviTag.macId?.value == macId?.value)
    }

    func updateProgress(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            matches(
                luid: userInfo[BPDidUpdateBackgroundUploadProgressKey.luid] as? LocalIdentifier,
                macId: userInfo[BPDidUpdateBackgroundUploadProgressKey.macId] as? MACIdentifier)
        else { return }
        let percentage = userInfo[BPDidUpdateBackgroundUploadProgressKey.progress] as? Double
        viewModel.uploadingBackgroundPercentage.value = percentage
        viewModel.isUploadingBackground.value = percentage.map { $0 < 1 } ?? false
        if percentage == 1 { weakView?.viewShouldDismiss() }
    }

    func refreshBackground(_ notification: Notification) {
        guard let userInfo = notification.userInfo, let ruuviTag,
            matches(
                luid: userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier,
                macId: userInfo[BPDidChangeBackgroundKey.macId] as? MACIdentifier)
        else { return }
        imageTask?.cancel()
        imageTask = Task { @MainActor [weak self, service = ruuviSensorPropertiesService!] in
            do {
                let image = try await service.getImage(for: ruuviTag)
                guard !Task.isCancelled, let self else { return }
                viewModel.background.value = image
                if ruuviTag.isCloudSensor != true, !didUploadBackground {
                    didUploadBackground = true
                    weakView?.viewShouldDismiss()
                }
            } catch {
                guard !Task.isCancelled else { return }
                self?.errorPresenter.present(error: error)
            }
        }
    }

    func prepareDefaultImages() {
        viewModel.defaultImages.value = (1...17).reversed().compactMap { index in
            guard let image = UIImage(named: "bg\(index)") else { return nil }
            return DefaultBackgroundModel(id: index, image: image, thumbnail: image.resize())
        }
    }
}

extension BackgroundSelectionPresenter: PhotoPickerPresenterDelegate {
    func photoPicker(presenter _: PhotoPickerPresenter, didPick photo: UIImage) {
        guard let ruuviTag else { return }
        performPhotoUpload(with: photo, ruuviTag: ruuviTag)
    }

    private func performPhotoUpload(with photo: UIImage, ruuviTag: RuuviTagSensor) {
        uploadTask?.cancel()
        viewModel.uploadingBackgroundPercentage.value = 0
        viewModel.isUploadingBackground.value = true
        uploadTask = Task {
            @MainActor [weak self, service = ruuviSensorPropertiesService!, settings = settings!, maxSize = maxSize] in
            do {
                _ = try await service.set(
                    image: photo, for: ruuviTag, maxSize: maxSize,
                    compressionQuality: CGFloat(settings.imageCompressionQuality) / 100)
                guard !Task.isCancelled else { return }
                self?.viewModel.isUploadingBackground.value = false
                self?.viewModel.background.value = photo
            } catch {
                guard !Task.isCancelled else { return }
                self?.viewModel.isUploadingBackground.value = false
                self?.errorPresenter.present(error: error)
            }
        }
    }
}
