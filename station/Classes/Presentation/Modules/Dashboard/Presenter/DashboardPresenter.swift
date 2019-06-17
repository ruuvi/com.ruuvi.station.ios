import Foundation
import RealmSwift
import BTKit

class DashboardPresenter: DashboardModuleInput {
    weak var view: DashboardViewInput!
    var router: DashboardRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    var settings: Settings!
    
    private let scanner = Ruuvi.scanner
    private var ruuviTagsToken: NotificationToken?
    private var observeTokens = [ObservationToken]()
    
    deinit {
        ruuviTagsToken?.invalidate()
        observeTokens.forEach( { $0.invalidate() } )
    }
}

extension DashboardPresenter: DashboardViewOutput {
    func viewDidLoad() {
        startObservingRuuviTags()
    }
    
    func viewWillAppear() {
        startScanningRuuviTags()
    }
    
    func viewWillDisappear() {
        stopScanningRuuviTags()
    }
    
    func viewDidTriggerMenu() {
        router.openMenu()
    }
}

extension DashboardPresenter {
    private func startScanningRuuviTags() {
        observeTokens.removeAll()
        if let ruuviTags = view.ruuviTags {
            for ruuviTag in ruuviTags {
                observeTokens.append(scanner.observe(self, uuid: ruuviTag.uuid) { (observer, device) in
                    if let tagData = device.ruuvi?.tag {
                        observer.view.update(ruuviTag: ruuviTag, with: tagData)
                    }
                })
            }
        }
    }
    
    private func stopScanningRuuviTags() {
        observeTokens.forEach( { $0.invalidate() } )
    }
    
    private func startObservingRuuviTags() {
        let ruuviTags = realmContext.main.objects(RuuviTagRealm.self).sorted(byKeyPath: "name")
        ruuviTagsToken = ruuviTags.observe { [weak self] (change) in
            switch change {
            case .initial(let ruuviTags):
                self?.view.ruuviTags = ruuviTags
                self?.startScanningRuuviTags()
            case .update(let ruuviTags, _, _, _):
                self?.view.ruuviTags = ruuviTags
                self?.startScanningRuuviTags()
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        }
    }
}
