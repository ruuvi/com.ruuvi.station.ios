import Foundation
import Future

class TagsManagerPresenter {
    weak var view: TagsManagerViewInput!
    var output: TagsManagerModuleOutput!
    var router: TagsManagerRouterInput!

    var activityPresenter: ActivityPresenter!
    var alertPresenter: AlertPresenter!
    var errorPresenter: ErrorPresenter!
    var keychainService: KeychainService!
    var ruuviTagTank: RuuviTagTank!
    var ruuviTagTrunk: RuuviTagTrunk!
    var userApiService: RuuviNetworkUserApi!

    private var userApiSensorIds: [AnyMACIdentifier] = []
    private var userApiSensors: [UserApiUserSensor] = []
    private var viewModel: TagsManagerViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
}
// MARK: - TagsManagerViewOutput
extension TagsManagerPresenter: TagsManagerViewOutput {
    func viewDidLoad() {
        syncViewModel()
        bindViewModel()
    }

    func viewDidCloseButtonTap() {
        router.dismiss()
    }

    func viewDidSignOutButtonTap() {
        createSignOutAlert()
    }
}
// MARK: - TagsManagerModuleInput
extension TagsManagerPresenter: TagsManagerModuleInput {
    func configure(output: TagsManagerModuleOutput) {
        self.output = output
        fetchUserData()
    }

    func dismiss() {
        router.dismiss(completion: nil)
    }

    func viewDidTapAction(_ action: TagManagerActionType) {
        switch action {
        case .addMissingTag:
            addMissingTags()
        }
    }
}
// MARK: - Private
extension TagsManagerPresenter {
    private func syncViewModel() {
        viewModel = TagsManagerViewModel()
        viewModel.title.value = keychainService.userApiEmail
        viewModel.actions.value = TagManagerActionType.allCases
    }

    private func bindViewModel() {
    }

    private func createSignOutAlert() {
        let title = "TagsManager.SignOutButton".localized()
        let message = "TagsManagerPresenter.SignOutConfirmAlert.Message".localized()
        let confirmActionTitle = "Confirm".localized()
        let cancelActionTitle = "Cancel".localized()
        let confirmAction = UIAlertAction(title: confirmActionTitle,
                                          style: .default) { [weak self] (_) in
            self?.keychainService.userApiLogOut()
            self?.dismiss()
        }
        let cancleAction = UIAlertAction(title: cancelActionTitle,
                                         style: .cancel,
                                         handler: nil)
        let actions = [ confirmAction, cancleAction ]
        let alertViewModel = AlertViewModel(title: title,
                                                         message: message,
                                                         style: .alert,
                                                         actions: actions)
        alertPresenter.showAlert(alertViewModel)
    }

    private func createSuccessAddMissingTagAlert() {
        let title = "TagsManagerPresenter.SuccessAddMissingTagAlert.Title".localized()
        let message = "TagsManagerPresenter.SuccessAddMissingTagAlert.Message".localized()
        let okActionTitle = "TagsManagerPresenter.SuccessAddMissingTagAlert.Ok".localized()
        let okAction = UIAlertAction(title: okActionTitle,
                                     style: .default,
                                     handler: nil)
        let alertViewModel = AlertViewModel(title: title,
                                                         message: message,
                                                         style: .alert,
                                                         actions: [okAction])
        alertPresenter.showAlert(alertViewModel)
    }

    private func fetchUserData() {
        activityPresenter.increment()
        userApiService.user()
            .on(success: { [weak self] (response) in
                self?.userApiSensors = response.sensors
                self?.userApiSensorIds = response.sensors.map({MACIdentifierStruct(value: $0.sensorId).any})
                self?.viewModel.items.value = response.sensors.map({ TagManagerCellViewModel(sensor: $0) })
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.decrement()
            })
    }

    private func addMissingTags() {
        activityPresenter.increment()
        ruuviTagTrunk.readAll().on(success: { [weak self] (sensors) in
            guard let userApiIds = self?.userApiSensorIds else {
                return
            }
            let storedIds: [AnyMACIdentifier] = sensors.compactMap({ $0.any.macId?.any })
            let setForAdding = Set(userApiIds).subtracting(Set(storedIds))
            guard !setForAdding.isEmpty else {
                self?.errorPresenter.present(error: RUError.userApi(.emptyResponse))
                return
            }
            self?.fetchUserApiSensors(with: Array(setForAdding))
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        }, completion: { [weak self] in
            self?.activityPresenter.decrement()
        })
    }

    private func fetchUserApiSensors(with macIds: [AnyMACIdentifier]) {
        activityPresenter.increment()
        userApiService.getTags(tags: macIds.map({$0.value})).on(success: { [weak self] (sensors) in
            self?.addMissingSensors(sensors)
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        }, completion: { [weak self] in
            self?.activityPresenter.decrement()
        })
    }

    private func addMissingSensors(_ sensors: [(AnyRuuviTagSensor, RuuviTagSensorRecord)]) {
        let sensorsToSave: [RuuviTagSensorStruct] = sensors.compactMap({ sensor in
            guard let userApiSensor = self.userApiSensors.first(where: { $0.sensorId == sensor.0.id }) else {
                return nil
            }
            return .init(version: sensor.0.version,
                         luid: sensor.0.luid,
                         macId: sensor.0.macId,
                         isConnectable: sensor.0.isConnectable,
                         name: userApiSensor.name,
                         networkProvider: .userApi,
                         isClaimed: sensor.0.isClaimed,
                         isOwner: userApiSensor.isOwner)
        })
        let futures = sensorsToSave.map({ruuviTagTank.create($0)})
        activityPresenter.increment()
        Future.zip(futures).on(success: { [weak self]  (results) in
            if results.allSatisfy({$0 == true}) {
                self?.storeRecords(sensors.map({$0.1}))
            }
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        }, completion: { [weak self] in
            self?.activityPresenter.decrement()
        })
    }

    private func storeRecords(_ records: [RuuviTagSensorRecord]) {
        activityPresenter.increment()
        ruuviTagTank.create(records).on(success: { [weak self] _ in
            self?.createSuccessAddMissingTagAlert()
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        }, completion: { [weak self] in
            self?.activityPresenter.decrement()
        })
    }
}
