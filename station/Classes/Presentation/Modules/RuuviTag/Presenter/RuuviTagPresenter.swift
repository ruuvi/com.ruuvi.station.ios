import Foundation
import BTKit

class RuuviTagPresenter: RuuviTagModuleInput {
    weak var view: RuuviTagViewInput!
    
    private var ruuviTag: RuuviTag! { didSet { updateViewFromRuuviTag() } }
    
    func configure(ruuviTag: RuuviTag) {
        self.ruuviTag = ruuviTag
    }
}

// MARK: - RuuviTagViewOutput
extension RuuviTagPresenter: RuuviTagViewOutput {
    func viewDidTapOnDimmingView() {
        print("tapped on dimming view")
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
