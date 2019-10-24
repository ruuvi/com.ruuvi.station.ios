import Foundation
import BTKit
import RealmSwift

class BackgroundPresenter: NSObject, BackgroundModuleInput {
    weak var view: BackgroundViewInput!
    var router: BackgroundRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    var connectionPersistence: ConnectionPersistence!
    
    private var ruuviTagsToken: NotificationToken?
    
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
    private func syncViewModels(with ruuviTags: Results<RuuviTagRealm>) {
        view.viewModels = ruuviTags.map { ruuviTag in
            let viewModel = BackgroundViewModel(uuid: ruuviTag.uuid)
            update(viewModel: viewModel, with: ruuviTag)
            bind(viewModel: viewModel, to: ruuviTag)
            return viewModel
        }
    }
    
    private func update(viewModel: BackgroundViewModel, with ruuviTag: RuuviTagRealm) {
        viewModel.name.value = ruuviTag.name
        viewModel.keepConnection.value = connectionPersistence.keepConnection(to: ruuviTag.uuid)
        viewModel.presentConnectionNotifications.value = connectionPersistence.presentConnectionNotifications(for: ruuviTag.uuid)
        viewModel.saveHeartbeats.value = connectionPersistence.saveHeartbeats(uuid: ruuviTag.uuid)
        viewModel.saveHeartbeatsInterval.value = connectionPersistence.saveHeartbeatsInterval(uuid: ruuviTag.uuid)
    }
    
    private func bind(viewModel: BackgroundViewModel, to ruuviTag: RuuviTagRealm) {
        bind(viewModel.keepConnection, fire: false) { (observer, keepConnection) in
            observer.connectionPersistence.setKeepConnection(keepConnection.bound, for: ruuviTag.uuid)
        }
        bind(viewModel.presentConnectionNotifications, fire: false) { observer, presentConnectionNotifications in
            observer.connectionPersistence.setPresentConnectionNotifications(presentConnectionNotifications.bound, for: ruuviTag.uuid)
        }
        bind(viewModel.saveHeartbeats, fire: false) { observer, saveHeartbeats in
            observer.connectionPersistence.setSaveHeartbeats(saveHeartbeats.bound, uuid: ruuviTag.uuid)
        }
        bind(viewModel.saveHeartbeatsInterval, fire: false) { observer, saveHeartbeatsInterval in
            observer.connectionPersistence.setSaveHeartbeatsInterval(saveHeartbeatsInterval.bound, uuid: ruuviTag.uuid)
        }
    }
    
    private func startObservingRuuviTags() {
        let ruuviTags = realmContext.main.objects(RuuviTagRealm.self).filter("isConnectable = true")
        ruuviTagsToken?.invalidate()
        ruuviTagsToken = ruuviTags.observe { [weak self] (change) in
            switch change {
            case .initial(let ruuviTags):
                self?.syncViewModels(with: ruuviTags)
            case .update(let ruuviTags, let insertions, let deletions, _):
                if insertions.count > 0 || deletions.count > 0 {
                    self?.syncViewModels(with: ruuviTags)
                }
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        }
    }
}
