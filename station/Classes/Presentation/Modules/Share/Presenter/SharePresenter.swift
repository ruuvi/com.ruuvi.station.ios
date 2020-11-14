import Foundation
import Future

class SharePresenter {
    weak var view: ShareViewInput!
    var router: ShareRouterInput!

    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    var networkService: RuuviNetworkUserApi!

    private var ruuviTagId: String!

    private var viewModel: ShareViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
}
// MARK: - ShareViewOutput
extension SharePresenter: ShareViewOutput {
    func viewDidLoad() {
        fetchShared()
    }

    func viewDidTapSendButton(email: String?) {
        guard let email = email,
              !email.isEmpty else {
            return
        }
        let requestModel = UserApiShareRequest(user: email, sensor: ruuviTagId)
        activityPresenter.increment()
        networkService.share(requestModel).on(success: { [weak self] _ in
            self?.fetchShared()
        }, failure: { [weak self] error in
            guard let self = self else {
                return
            }
            self.errorPresenter.present(error: error)
        }, completion: { [weak self] in
            self?.activityPresenter.decrement()
        })
    }

    private func unshareTag(_ email: String) {
        let requestModel = UserApiShareRequest(user: email, sensor: ruuviTagId)
        activityPresenter.increment()
        networkService.unshare(requestModel).on(success: { [weak self] _ in
            self?.fetchShared()
        }, failure: { [weak self] error in
            guard let self = self else {
                return
            }
            self.errorPresenter.present(error: error)
        }, completion: { [weak self] in
            self?.activityPresenter.decrement()
        })
    }

    func viewDidTapUnshareEmail(_ email: String?) {
        guard let email = email,
              !email.isEmpty else {
            return
        }
        let title = "SharePresenter.UnshareSensor.Title".localized()
        let message = String(format: "SharePresenter.UnshareSensor.Message".localized(), email)

        let confirmActionTitle = "SharePresenter.UnshareSensor.ConfirmAction".localized()
        let cancelActionTitle = "SharePresenter.UnshareSensor.CancelAction".localized()
        let confirmAction = UIAlertAction(title: confirmActionTitle,
                                          style: .default) { [weak self] (_) in
            self?.unshareTag(email)
        }

        let cancleAction = UIAlertAction(title: cancelActionTitle,
                                         style: .cancel,
                                         handler: nil)
        let actions = [ confirmAction, cancleAction ]
        let alertViewModel = AlertViewModel(title: title,
                                            message: message,
                                            style: .alert,
                                            actions: actions)
        router.showAlert(alertViewModel)
    }
}
// MARK: - ShareModuleInput
extension SharePresenter: ShareModuleInput {
    func configure(ruuviTagId: String) {
        self.ruuviTagId = ruuviTagId
        viewModel = ShareViewModel()
    }

    func dismiss() {
        router.dismiss(completion: nil)
    }
}
// MARK: - Private
extension SharePresenter {
    private func fetchShared() {
        activityPresenter.increment()
        networkService.shared(.init())
            .on(success: { [weak self] response in
                guard let self = self else {
                    return
                }
                self.filterEmails(response.sensors)
                self.view.clearInput()
            }, failure: { [weak self] error in
                guard let self = self else {
                    return
                }
                self.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.decrement()
            })
    }

    private func filterEmails(_ sensors: [UserApiSharedResponse.Sensor]) {
        let oldCount = viewModel.sharedEmails.value?.count

        viewModel.sharedEmails.value = sensors.compactMap({
            if $0.sensor == self.ruuviTagId {
                return $0.sharedTo
            } else {
                return nil
            }
        })
        let newCount = viewModel.sharedEmails.value?.count
        if (newCount == 0 && oldCount != 0)
            || (newCount != 0 && oldCount == 0) {
            view.reloadTableView()
        } else {
            view.reloadSharedEmailsSection()
        }
    }
}
