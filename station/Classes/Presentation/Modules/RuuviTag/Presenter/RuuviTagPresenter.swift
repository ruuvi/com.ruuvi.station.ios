import Foundation
import BTKit

class RuuviTagPresenter: RuuviTagModuleInput {
    weak var view: RuuviTagViewInput!
    var router: RuuviTagRouterInput!
    var ruuviTagPersistence: RuuviTagPersistence!
    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    var realmContext: RealmContext!
    var settings: Settings!
    
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
        if let savedTag = realmContext.main.object(ofType: RuuviTagRealm.self, forPrimaryKey: ruuviTag.uuid) {
            view.name = savedTag.name
            view.humidityOffset = savedTag.humidityOffset
        }
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
        view.temperatureUnit = settings.temperatureUnit
        switch settings.temperatureUnit {
        case .celsius:
            view.temperature = ruuviTag.celsius
        case .fahrenheit:
            view.temperature = ruuviTag.fahrenheit
        }
        view.humidity = ruuviTag.humidity
        view.pressure = ruuviTag.pressure
        view.rssi = ruuviTag.rssi
    }
}
