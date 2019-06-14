import Foundation
import RealmSwift

class DashboardPresenter: DashboardModuleInput {
    weak var view: DashboardViewInput!
    var router: DashboardRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    
    private var ruuviTagsToken: NotificationToken?
    
    deinit {
        ruuviTagsToken?.invalidate()
    }
}

extension DashboardPresenter: DashboardViewOutput {
    func viewDidLoad() {
        startObservingRuuviTags()
    }
    
    func viewDidTriggerMenu() {
        router.openMenu()
    }
}

extension DashboardPresenter {
    private func startObservingRuuviTags() {
        view.ruuviTags = realmContext.main.objects(RuuviTagRealm.self).sorted(byKeyPath: "name")
        ruuviTagsToken = view.ruuviTags.observe { [weak self] (change) in
            switch change {
            case .initial(let ruuviTags):
                self?.view.ruuviTags = ruuviTags
            case .update(let ruuviTags, _, _, _):
                self?.view.ruuviTags = ruuviTags
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        }
    }
}
