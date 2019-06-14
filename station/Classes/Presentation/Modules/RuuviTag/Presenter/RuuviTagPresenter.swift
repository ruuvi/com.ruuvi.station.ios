import Foundation
import BTKit

class RuuviTagPresenter: RuuviTagModuleInput {
    weak var view: RuuviTagViewInput!
    var router: RuuviTagRouterInput!
    var ruuviTagPersistence: RuuviTagPersistence!
    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    var realmContext: RealmContext!
    
    private var ruuviTag: RuuviTag! { didSet { updateViewFromRuuviTag() } }
    private var isSaving: Bool = false {
        didSet {
            if isSaving {
                activityPresenter.increment()
            } else {
                activityPresenter.decrement()
            }
        }
    }
    
    func configure(ruuviTag: RuuviTag) {
        self.ruuviTag = ruuviTag
        view.name = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: ruuviTag.uuid)?.name
    }
}

// MARK: - RuuviTagViewOutput
extension RuuviTagPresenter: RuuviTagViewOutput {
    func viewDidTapOnDimmingView() {
        router.dismiss()
    }
    
    func viewDidTapOnView() {
        router.dismiss()
    }
    
    func viewDidSave(name: String) {
        let save = ruuviTagPersistence.persist(ruuviTag: ruuviTag, name: name)
        isSaving = true
        save.on(success: { [weak self] (ruuviTag) in
            self?.router.dismiss()
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        }) {
            self.isSaving = false
        }
    }
    
}

// MARK: - Private
extension RuuviTagPresenter {
    private func updateViewFromRuuviTag() {
        view.uuid = ruuviTag.mac ?? ruuviTag.uuid
        view.temperature = ruuviTag.celsius
        view.temperatureUnit = .celsius
        view.humidity = ruuviTag.humidity
        view.pressure = ruuviTag.pressure
        view.rssi = ruuviTag.rssi
    }
}
