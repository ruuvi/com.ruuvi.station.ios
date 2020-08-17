import Foundation
import Future
import BTKit

class KaltiotPickerPresenter {
    weak var view: KaltiotPickerViewInput!
    var output: KaltiotPickerModuleOutput!
    var router: KaltiotPickerRouterInput!

    var activityPresenter: ActivityPresenter!
    var diffCalculator: DiffCalculator!
    var errorPresenter: ErrorPresenter!
    var keychainService: KeychainService!
    var realmContext: RealmContext!
    var ruuviNetworkKaltiot: RuuviNetworkKaltiot!
    var ruuviTagTank: RuuviTagTank!
    var ruuviTagTrunk: RuuviTagTrunk!
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

    func viewDidSelectBeacon(_ viewModel: KaltiotBeaconViewModel) {
        if viewModel.isConnectable {
            fetchSensor(for: viewModel.beacon)
        } else {
            errorPresenter.present(error: RUError.ruuviNetwork(.doesNotHaveSensors))
        }
    }

    func viewDidStartSearch(mac: String) {
        let oldValue = viewModel.beacons.map({$0.value})
        if mac.count == 12 {
            ruuviNetworkKaltiot.getBeacon(mac: mac.lowercased())
                .on(success: { [weak self] (beacon) in
                    let newValue = KaltiotBeaconViewModel(beacon: beacon)
                    self?.calculateDiff(oldValue,
                                        newValue: [newValue])
                }, failure: { [weak self] (error) in
                    self?.errorPresenter.present(error: error)
                })
        } else {
            let newValue = beacons.filter({
                $0.beacon.id
                    .lowercased()
                    .starts(with: mac.lowercased())
            })
            calculateDiff(oldValue, newValue: newValue)
        }
    }

    func viewDidCancelSearch() {
        let oldValue = viewModel.beacons.map({$0.value})
        calculateDiff(oldValue, newValue: beacons)
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
    private func fetchExisting(completion: (() -> Void)?) {
        let op = ruuviTagTrunk.readAll()
        op.on(success: { [weak self] results in
            self?.existingBeaconsMac = results.compactMap({$0.macId?.mac})
        }, completion: completion)
    }

    private func obtainBeacons() {
        isLoading = true
        fetchExisting(completion: { [weak self] in
            self?.fetchBeacons()
        })
    }

    private func fetchBeacons(complition: (() -> Void)? = nil) {
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
            }, completion: { [weak self] in
                self?.fetchBeacons()
            })
        }
    }

    private func fetchSensor(for beacon: KaltiotBeacon) {
        let op = ruuviNetworkKaltiot.getSensor(for: beacon)
        isLoading = true
        op.on(success: {[weak self] (sensor) in
            self?.persistSensor(sensor)
        }, failure: { [weak self] (error) in
            self?.isLoading = false
            self?.errorPresenter.present(error: error)
        })
    }

    private func calculateDiff(_ oldValue: [KaltiotBeaconViewModel], newValue: [KaltiotBeaconViewModel]) {
        let oldData = oldValue.enumerated().map({
            ReloadableCell(key: $0.element.beacon.id, value: $0.element, index: $0.offset)
        })
        let newData = newValue.enumerated().map({
            ReloadableCell(key: $0.element.beacon.id, value: $0.element, index: $0.offset)
        })
        let cellChanges = diffCalculator.calculate(oldItems: oldData, newItems: newData, in: 0)
        viewModel.beacons = newData
        if oldValue.count == 0 && newData.count > 0 {
            isLoading = false
        }
        view.applyChanges(cellChanges)
    }

    private func persistSensor(_ sensor: AnyRuuviTagSensor) {
        self.isLoading = true
        let operation = ruuviTagTank.create(sensor)
        operation.on(success: { [weak self] _ in
            self?.isLoading = false
            self?.router.dismiss(completion: nil)
        }, failure: { [weak self] (error) in
            self?.isLoading = false
            self?.errorPresenter.present(error: error)
        })
    }
}
