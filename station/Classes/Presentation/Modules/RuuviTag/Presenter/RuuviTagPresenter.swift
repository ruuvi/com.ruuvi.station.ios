import Foundation
import BTKit

class RuuviTagPresenter: RuuviTagModuleInput {
    weak var view: RuuviTagViewInput!
    var router: RuuviTagRouterInput!
    var ruuviTagPersistence: RuuviTagPersistence!
    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    
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
        
    }
    
}

// MARK: - Private
extension RuuviTagPresenter {
    private func updateViewFromRuuviTag() {
        view.name = ruuviTag.mac ?? ruuviTag.uuid
        view.temperature = ruuviTag.celsius
        view.temperatureUnit = .celsius
        view.humidity = ruuviTag.humidity
        view.pressure = ruuviTag.pressure
        view.rssi = ruuviTag.rssi
    }
}
