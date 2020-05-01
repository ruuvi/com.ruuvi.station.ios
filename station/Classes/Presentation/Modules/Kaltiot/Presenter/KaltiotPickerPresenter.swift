import Foundation

class KaltiotPickerPresenter {
    weak var view: KaltiotPickerViewInput!
    var output: KaltiotPickerModuleOutput!
    var router: KaltiotPickerRouterInput!
    var keychainService: KeychainService!
    var ruuviNetworkKaltiot: RuuviNetworkKaltiot!
    var errorPresenter: ErrorPresenter!
    var activityPresenter: ActivityPresenter!

    private var viewModel: KaltiotPickerViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
    private var isLoading: Bool = false {
        didSet {
            if isLoading {
                activityPresenter.increment()
            } else {
                activityPresenter.decrement()
            }
        }
    }
    var beacons: [KaltiotBeaconViewModel] = [] {
        didSet {
            calculateDiff(oldValue, newValue: beacons)
        }
    }
    private var page: Int = 0
    private var canLoadNextPage: Bool = true
}
// MARK: - KaltiotPickerViewOutput
extension KaltiotPickerPresenter: KaltiotPickerViewOutput {
    func viewDidLoad() {
        obtainBeacons()
    }

    func viewDidTriggerLoadNextPage() {
        fetchBeacons()
    }

    func viewDidTriggerClose() {
        router.dismiss(completion: nil)
    }

    func viewDidSelectTag(at index: Int) {
        if beacons[index].isConnectable {
            fetchHistory(forBeacon: beacons[index].id)
        } else {
            errorPresenter.present(error: RUError.ruuviNetwork(.doesNotHaveSensors))
        }
    }
}
// MARK: - KaltiotPickerModuleInput
extension KaltiotPickerPresenter: KaltiotPickerModuleInput {
    func configure(output: KaltiotPickerModuleOutput) {
        self.output = output
    }

    func dismiss() {
        router.dismiss(completion: nil)
    }
}
// MARK: - Private
extension KaltiotPickerPresenter {
    private func obtainBeacons() {
        viewModel = KaltiotPickerViewModel()
        isLoading = true
        fetchBeacons()
    }

    private func fetchBeacons() {
        if canLoadNextPage {
            let op = ruuviNetworkKaltiot.beacons(page: page)
            op.on(success: { [weak self] (result) in
                if let page = self?.page {
                    self?.canLoadNextPage = page < result.pages
                    self?.page += 1
                }
                var beaconsViewModels: [KaltiotBeaconViewModel] = self?.beacons ?? []
                result.beacons.forEach({
                    beaconsViewModels.append(KaltiotBeaconViewModel(beacon: $0))
                })
                self?.beacons = beaconsViewModels
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: nil)
        }
    }

    private func fetchHistory(forBeacon beaconId: String) {
        let op = ruuviNetworkKaltiot.load(uuid: beaconId, mac: beaconId, isConnectable: true)
        isLoading = true
        op.on(success: { (result) in
            print(result)
            #warning("👉 Implement here adding tag with history into DB and close VC")
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        }, completion: {[weak self] in
            self?.isLoading = false
        })
    }

    private func calculateDiff(_ oldValue: [KaltiotBeaconViewModel], newValue: [KaltiotBeaconViewModel]) {
        let oldData = oldValue.enumerated().map({
            ReloadableCell(key: $0.element.id, value: $0.element, index: $0.offset)
        })
        let newData = newValue.enumerated().map({
            ReloadableCell(key: $0.element.id, value: $0.element, index: $0.offset)
        })
        let cellChanges = DiffCalculator.calculate(oldItems: oldData, newItems: newData, in: 0)
        viewModel.beacons = newData
        if oldValue.count == 0 && newData.count > 0 {
            isLoading = false
        }
        view.applyChanges(cellChanges)
    }
}
