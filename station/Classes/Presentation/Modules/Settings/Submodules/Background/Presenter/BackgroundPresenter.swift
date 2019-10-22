import Foundation
import BTKit
import RealmSwift

class BackgroundPresenter: BackgroundModuleInput {
    weak var view: BackgroundViewInput!
    var router: BackgroundRouterInput!
    var scanner: BTScanner!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    
    private var scanToken: ObservationToken?
    private var connectableRuuviTags = Set<RuuviTag>()
    private var reloadTimer: Timer?
    private var ruuviTagsToken: NotificationToken?
    private var ruuviTags: Results<RuuviTagRealm>? {
        didSet {
            syncViewModels()
        }
    }
    
    deinit {
        reloadTimer?.invalidate()
        scanToken?.invalidate()
        ruuviTagsToken?.invalidate()
    }
    
    func configure() {
        startObservingRuuviTags()
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
            viewModel.name.value = ruuviTags?.first(where: { $0.uuid == ruuviTag.uuid })?.name
            viewModel.isOn.value = false
            return viewModel
        })
    }
    
    private func startObservingRuuviTags() {
        ruuviTags = realmContext.main.objects(RuuviTagRealm.self)
        ruuviTagsToken = ruuviTags?.observe { [weak self] (change) in
            switch change {
            case .initial(let ruuviTags):
                self?.ruuviTags = ruuviTags
            case .update(let ruuviTags, _, _, _):
                self?.ruuviTags = ruuviTags
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        }
    }
}
