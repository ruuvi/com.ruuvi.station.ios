import Foundation
import BTKit

class BackgroundPresenter: BackgroundModuleInput {
    weak var view: BackgroundViewInput!
    var router: BackgroundRouterInput!
    var scanner: BTScanner!
    
    private var scanToken: ObservationToken?
    private var connectableRuuviTags = Set<RuuviTag>()
    private var reloadTimer: Timer?
    
    deinit {
        reloadTimer?.invalidate()
        scanToken?.invalidate()
    }
    
    func configure() {
        scanToken = scanner.scan(self) { [weak self] (observer, device) in
            if let ruuviTag = device.ruuvi?.tag, ruuviTag.isConnectable {
                self?.connectableRuuviTags.update(with: ruuviTag)
            }
        }
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { [weak self] (timer) in
            self?.syncViewModels()
        })
    }
}

// MARK: - BackgroundViewOutput
extension BackgroundPresenter: BackgroundViewOutput {
    
}

// MARK: - Private
extension BackgroundPresenter {
    private func syncViewModels() {
        view.viewModels = connectableRuuviTags.sorted(by: {
            if let rssi0 = $0.rssi, let rssi1 = $1.rssi {
                return rssi0 > rssi1
            } else {
                return false
            }
        }).map({ (ruuviTag) -> BackgroundViewModel in
            let viewModel = BackgroundViewModel()
            viewModel.name.value = ruuviTag.uuid
            viewModel.isOn.value = true
            return viewModel
        })
    }
}
