import Foundation
import BTKit
import RealmSwift

class BackgroundPresenter: NSObject, BackgroundModuleInput {
    weak var view: BackgroundViewInput!
    var router: BackgroundRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    
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
            return viewModel
        } ?? []
    }
    
    private func startObservingRuuviTags() {
        ruuviTags = realmContext.main.objects(RuuviTagRealm.self).filter("isConnectable = true")
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
