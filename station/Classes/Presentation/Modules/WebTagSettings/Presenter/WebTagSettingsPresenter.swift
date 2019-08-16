import UIKit
import RealmSwift

class WebTagSettingsPresenter: WebTagSettingsModuleInput {
    weak var view: WebTagSettingsViewInput!
    var router: WebTagSettingsRouterInput!
    var backgroundPersistence: BackgroundPersistence!
    var errorPresenter: ErrorPresenter!
    var webTagService: WebTagService!
    var photoPickerPresenter: PhotoPickerPresenter! {
        didSet {
            photoPickerPresenter.delegate = self
        }
    }
    
    private var webTagToken: NotificationToken?
    private var webTag: WebTagRealm! {
        didSet {
            syncViewModel()
        }
    }
    
    deinit {
        webTagToken?.invalidate()
    }
    
    func configure(webTag: WebTagRealm) {
        self.webTag = webTag
        startObservingWebTag()
    }
}

// MARK: - WebTagSettingsViewOutput
extension WebTagSettingsPresenter: WebTagSettingsViewOutput {
    func viewDidAskToDismiss() {
        router.dismiss()
    }
    
    func viewDidAskToRandomizeBackground() {
        view.viewModel.background.value = backgroundPersistence.setNextDefaultBackground(for: webTag.uuid)
    }
    
    func viewDidAskToSelectBackground(sourceView: UIView) {
        photoPickerPresenter.pick(sourceView: sourceView)
    }
    
    func viewDidChangeTag(name: String) {
        let finalName = name.isEmpty ?
                        (webTag.location == nil
                            ? WebTagLocationSource.current.title
                            : WebTagLocationSource.manual.title)
                        : name
        let operation = webTagService.update(name: finalName, of: webTag)
        operation.on(failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
    
    func viewDidAskToRemoveWebTag() {
        view.showTagRemovalConfirmationDialog()
    }
    
    func viewDidConfirmTagRemoval() {
        let operation = webTagService.remove(webTag: webTag)
        operation.on(success: { [weak self] _ in
            self?.router.dismiss()
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
    
    func viewDidAskToSelectLocation() {
        router.openLocationPicker(output: self)
    }
    
    func viewDidAskToClearLocation() {
        view.showClearLocationConfirmationDialog()
    }
    
    func viewDidConfirmToClearLocation() {
        let operation = webTagService.clearLocation(of: webTag)
        operation.on(failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
}

// MARK: - PhotoPickerPresenterDelegate
extension WebTagSettingsPresenter: PhotoPickerPresenterDelegate {
    func photoPicker(presenter: PhotoPickerPresenter, didPick photo: UIImage) {
        let set = backgroundPersistence.setCustomBackground(image: photo, for: webTag.uuid)
        set.on(success: { [weak self] _ in
            self?.view.viewModel.background.value = photo
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
}

// MARK: - LocationPickerModuleOutput
extension WebTagSettingsPresenter: LocationPickerModuleOutput {
    func locationPicker(module: LocationPickerModuleInput, didPick location: Location) {
        let operation = webTagService.update(location: location, of: webTag)
        operation.on(failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
    }
}

// MARK: - Private
extension WebTagSettingsPresenter {
    private func startObservingWebTag() {
        webTagToken = webTag.observe({ [weak self] (change) in
            switch change {
            case .change:
                self?.syncViewModel()
            case .deleted:
                self?.router.dismiss()
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        })
    }
    
    
    private func syncViewModel() {
        view.viewModel.background.value = backgroundPersistence.background(for: webTag.uuid)
        
        if webTag.name == WebTagLocationSource.manual.title {
            view.viewModel.name.value = nil
        } else {
            view.viewModel.name.value = webTag.name
        }

        view.viewModel.uuid.value = webTag.uuid
        if let webTagLocation = webTag.location {
            view.viewModel.location.value = webTagLocation.location
        } else {
            view.viewModel.location.value = nil
        }
    }
}
