import Foundation
import RealmSwift

class ChartPresenter: ChartModuleInput {
    weak var view: ChartViewInput!
    var router: ChartRouterInput!
    var errorPresenter: ErrorPresenter!
    
    private var ruuviTag: RuuviTagRealm!
    private var type: ChartDataType = .rssi
    private var dataToken: NotificationToken?
    
    deinit {
        dataToken?.invalidate()
    }
    
    func configure(ruuviTag: RuuviTagRealm, type: ChartDataType) {
        self.ruuviTag = ruuviTag
        self.type = type
    }
}

extension ChartPresenter: ChartViewOutput {
    func viewDidLoad() {
        startObservingData()
    }
    
    func viewDidTapOnDimmingView() {
        router.dismiss()
    }
}

extension ChartPresenter {
    private func startObservingData() {
        dataToken = ruuviTag.data.observe({ [weak self] (change) in
            guard let sSelf = self else { return }
            switch change {
            case .initial(let data):
                sSelf.view.data = data.suffix(20).map({ (tagData) -> ChartViewModel in
                    switch sSelf.type {
                    case .rssi:
                        return ChartViewModel(date: tagData.date, value: Double(tagData.rssi))
                    }
                })
            case .update(let data, _, _, _):
                sSelf.view.data = data.suffix(20).map({ (tagData) -> ChartViewModel in
                    switch sSelf.type {
                    case .rssi:
                        return ChartViewModel(date: tagData.date, value: Double(tagData.rssi))
                    }
                })
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        })
    }
}
