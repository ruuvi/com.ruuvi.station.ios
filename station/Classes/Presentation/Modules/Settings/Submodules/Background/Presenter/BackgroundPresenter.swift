import Foundation
import BTKit
import RealmSwift

class BackgroundPresenter: NSObject, BackgroundModuleInput {
    weak var view: BackgroundViewInput!
    var router: BackgroundRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    var heartbeatService: HeartbeatService!
    
    private var ruuviTagsToken: NotificationToken?
    private var ruuviTags: Results<RuuviTagRealm>? {
        didSet {
            syncViewModels()
        }
    }
    
    deinit {
        ruuviTagsToken?.invalidate()
    }
    
    func configure() {
        startObservingRuuviTags()
    }
}

// MARK: - BackgroundViewOutput
extension BackgroundPresenter: BackgroundViewOutput {
    
}

// MARK: - Private
extension BackgroundPresenter {
    private func syncViewModels() {
        view.viewModels = ruuviTags?.map { ruuviTag in
            let viewModel = BackgroundViewModel()
            viewModel.name.value = ruuviTag.name
            viewModel.keepConnection.value = ruuviTag.keepConnection
            bind(viewModel: viewModel, to: ruuviTag)
            return viewModel
        } ?? []
    }
    
    private func bind(viewModel: BackgroundViewModel, to ruuviTag: RuuviTagRealm) {
        bind(viewModel.keepConnection, fire: false) { (observer, keepConnection) in
            if keepConnection.bound {
                observer.heartbeatService.startKeepingConnection(to: ruuviTag).on(failure: { error in
                    observer.errorPresenter.present(error: error)
                })
            } else {
                observer.heartbeatService.stopKeepingConnection(to: ruuviTag).on(failure: { error in
                    observer.errorPresenter.present(error: error)
                })
            }
        }
    }
    
    private func startObservingRuuviTags() {
        ruuviTags = realmContext.main.objects(RuuviTagRealm.self).filter("isConnectable = true")
        ruuviTagsToken?.invalidate()
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
