import Foundation
import Future
import BTKit

class KaltiotPickerPresenter {
    weak var view: KaltiotPickerViewInput!
    var output: KaltiotPickerModuleOutput!
    var router: KaltiotPickerRouterInput!

    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    var keychainService: KeychainService!
    var realmContext: RealmContext!
    var ruuviNetworkKaltiot: RuuviNetworkKaltiot!
    var ruuviTagService: RuuviTagService!
    var ruuviTagPersistence: RuuviTagPersistence!
    var existingBeaconsMac: [String] = []

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
        viewModel = KaltiotPickerViewModel()
        existingBeaconsMac = realmContext.main.objects(RuuviTagRealm.self).compactMap({$0.mac})
    }

    func dismiss() {
        router.dismiss(completion: nil)
    }
}
// MARK: - Private
extension KaltiotPickerPresenter {
    private func obtainBeacons() {
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
                result.beacons.forEach({ beacon in
                    if !(self?.existingBeaconsMac ?? [])
                        .contains(beacon.id) {
                        beaconsViewModels.append(KaltiotBeaconViewModel(beacon: beacon))
                    }
                })
                self?.beacons = beaconsViewModels
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
        }
    }

    private func fetchHistory(forBeacon beaconMac: String) {
        let op = ruuviNetworkKaltiot.load(uuid: UUID().uuidString, mac: beaconMac, isConnectable: true)
        isLoading = true
        op.on(success: {[weak self] (results) in
            if results.count > 0 {
                self?.saveResults(results, mac: beaconMac)
                self?.isLoading = false
            } else {
                self?.isLoading = false
                self?.errorPresenter.present(error: RUError.ruuviNetwork(.noStoredData))
            }
        }, failure: { [weak self] (error) in
            self?.isLoading = false
            self?.errorPresenter.present(error: error)
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

    private func saveResults(_ results: [(RuuviTagProtocol, Date)], mac: String) {
        guard let firstTag = results.first?.0 else {
            return
        }
        self.isLoading = true
        let operation: Future<Void, RUError> = ruuviTagPersistence.persist(ruuviTag: firstTag, mac: mac)
        operation.on(success: { [weak self] in
            self?.isLoading = false
            self?.router.dismiss(completion: nil)
        }, failure: { [weak self] (error) in
            self?.isLoading = false
            self?.errorPresenter.present(error: error)
        })
    }
}
