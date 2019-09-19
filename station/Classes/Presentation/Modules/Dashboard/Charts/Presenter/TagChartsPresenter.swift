import Foundation
import RealmSwift

class TagChartsPresenter: TagChartsModuleInput {
    weak var view: TagChartsViewInput!
    var router: TagChartsRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    var backgroundPersistence: BackgroundPersistence!
    
    private var output: TagChartsModuleOutput?
    private var ruuviTagsToken: NotificationToken?
    private var webTagsToken: NotificationToken?
    private var initialUUID: String?
    private var ruuviTags: Results<RuuviTagRealm>? {
        didSet {
            syncViewModels()
        }
    }
    private var webTags: Results<WebTagRealm>? {
        didSet {
            syncViewModels()
        }
    }
    private var viewModels = [TagChartsViewModel]() {
        didSet {
            view.viewModels = viewModels
        }
    }
    
    deinit {
        ruuviTagsToken?.invalidate()
        webTagsToken?.invalidate()
    }
    
    func configure(uuid: String, output: TagChartsModuleOutput) {
        self.initialUUID = uuid
        self.output = output
    }
}

extension TagChartsPresenter: TagChartsViewOutput {
    
    func viewDidLoad() {
        startObservingRuuviTags()
        startObservingWebTags()
    }
    
    func viewDidTriggerDashboard() {
        router.dismiss()
    }
    
    func viewDidScroll(to index: Int) {
        if viewModels.count > index, let uuid = viewModels[index].uuid.value {
            output?.tagCharts(module: self, didScrollTo: uuid)
        }
    }
}

extension TagChartsPresenter {
    private func syncViewModels() {
        if ruuviTags != nil && webTags != nil {
            let ruuviViewModels = ruuviTags?.compactMap({ (ruuviTag) -> TagChartsViewModel in
                let viewModel = TagChartsViewModel(ruuviTag)
                viewModel.background.value = backgroundPersistence.background(for: ruuviTag.uuid)
                return viewModel
            }) ?? []
            let webViewModels = webTags?.compactMap({ (webTag) -> TagChartsViewModel in
                let viewModel = TagChartsViewModel(webTag)
                viewModel.background.value = backgroundPersistence.background(for: webTag.uuid)
                return viewModel
            }) ?? []
            viewModels = ruuviViewModels + webViewModels
            
            // if no tags, open discover
            if viewModels.count == 0 {
                router.openDiscover()
            }
            
            if let index = viewModels.firstIndex(where: { $0.uuid.value == initialUUID }) {
                view.scroll(to: index, immediately: true)
                initialUUID = nil
            }
        }
    }
    
    func restartScanning() {
//        startScanningRuuviTags()
//        startScanningWebTags()
    }
    
    private func startObservingRuuviTags() {
        ruuviTags = realmContext.main.objects(RuuviTagRealm.self)
        ruuviTagsToken = ruuviTags?.observe { [weak self] (change) in
            switch change {
            case .initial:
                self?.restartScanning()
            case .update(let ruuviTags, _, let insertions, _):
                self?.ruuviTags = ruuviTags
                if let ii = insertions.last {
                    let uuid = ruuviTags[ii].uuid
                    if let index = self?.viewModels.firstIndex(where: { $0.uuid.value == uuid }) {
                        self?.view.scroll(to: index)
                    }
                }
                self?.restartScanning()
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        }
    }
    
    private func startObservingWebTags() {
        webTags = realmContext.main.objects(WebTagRealm.self)
        webTagsToken = webTags?.observe({ [weak self] (change) in
            switch change {
            case .initial:
                self?.restartScanning()
            case .update(let webTags, _, let insertions, _):
                self?.webTags = webTags
                if let ii = insertions.last {
                    let uuid = webTags[ii].uuid
                    if let index = self?.viewModels.firstIndex(where: { $0.uuid.value == uuid }) {
                        self?.view.scroll(to: index)
                    }
                }
                self?.restartScanning()
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        })
    }
    
}
